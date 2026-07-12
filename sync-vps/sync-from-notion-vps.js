require('dotenv').config();
const { Client } = require('@notionhq/client');
const matter = require('gray-matter');
const fs = require('fs');

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const dbId = process.env.NOTION_DATABASE_ID;
const GH_TOKEN = process.env.GITHUB_TOKEN;
const GH_REPO = process.env.GITHUB_REPO;
const GH_BRANCH = process.env.GITHUB_BRANCH || 'main';
const CF_DEPLOY_HOOK = process.env.CF_DEPLOY_HOOK;

const lastSyncPath = './.last-sync';
let lastSync = '1970-01-01T00:00:00.000Z';
try { lastSync = fs.readFileSync(lastSyncPath, 'utf8'); } catch {}

async function ghGet(path) {
  const res = await fetch(`https://api.github.com/repos/${GH_REPO}/contents/${path}?ref=${GH_BRANCH}`, {
    headers: { Authorization: `token ${GH_TOKEN}`, Accept: 'application/vnd.github.v3+json' }
  });
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`GET ${res.status}`);
  const data = await res.json();
  return { content: Buffer.from(data.content, 'base64').toString('utf8'), sha: data.sha };
}

async function ghPut(path, content, sha, message) {
  const res = await fetch(`https://api.github.com/repos/${GH_REPO}/contents/${path}`, {
    method: 'PUT',
    headers: {
      Authorization: `token ${GH_TOKEN}`,
      Accept: 'application/vnd.github.v3+json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ message, content: Buffer.from(content).toString('base64'), sha, branch: GH_BRANCH })
  });
  if (!res.ok) throw new Error(`PUT ${res.status}`);
  return await res.json();
}

async function triggerNotionNextDeploy() {
  if (!CF_DEPLOY_HOOK) return;
  try {
    const res = await fetch(CF_DEPLOY_HOOK, { method: 'POST' });
    if (res.ok) {
      console.log(`[${new Date().toLocaleTimeString()}] 🚀 触发 NotionNext 重新部署`);
    } else {
      console.log(`[${new Date().toLocaleTimeString()}] ⚠️ Deploy Hook 失败: ${res.status}`);
    }
  } catch (err) {
    console.error(`[${new Date().toLocaleTimeString()}] ❌ Deploy Hook 错误:`, err.message);
  }
}

async function poll() {
  try {
    const res = await notion.databases.query({
      database_id: dbId,
      filter: {
        and: [
          { timestamp: 'last_edited_time', last_edited_time: { after: lastSync } },
          { property: 'Status', select: { does_not_equal: 'Archived' } }
        ]
      },
      sorts: [{ timestamp: 'last_edited_time', direction: 'ascending' }]
    });

    if (res.results.length === 0) {
      console.log(`[${new Date().toLocaleTimeString()}] · 无变更`);
      return;
    }

    console.log(`[${new Date().toLocaleTimeString()}] ↓ ${res.results.length} 个变更`);

    let hasChanges = false;

    for (const page of res.results) {
      const props = page.properties;
      const slug = props.Slug?.rich_text?.[0]?.plain_text || 'untitled';
      const filePath = `content/${slug}.md`;

      const existing = await ghGet(filePath);
      let body = '';
      let currentFm = {};

      if (existing) {
        const parsed = matter(existing.content);
        body = parsed.content;
        currentFm = parsed.data;
      } else {
        body = `\n# ${props.Name?.title?.[0]?.plain_text || slug}\n\n（从 Notion 同步，请在 Obsidian 编辑正文）\n`;
      }

      const newFm = {
        ...currentFm,
        title: props.Name?.title?.[0]?.plain_text || slug,
        date: props.Date?.date?.start,
        tags: props.Tags?.multi_select?.map(t => t.name) || [],
        slug,
        draft: props.Status?.select?.name === 'Draft',
        notion_page_id: page.id
      };

      if (existing && JSON.stringify(currentFm) === JSON.stringify(newFm)) {
        console.log(`  ⏭️ 无变化: ${slug}`);
        continue;
      }

      hasChanges = true;

      const newContent = matter.stringify(body, newFm);
      const message = existing
        ? `sync: notion → ob [vps] ${slug} [skip notion]`
        : `sync: notion → ob [vps] 新建 ${slug} [skip notion]`;

      await ghPut(filePath, newContent, existing?.sha, message);
      console.log(`  ✅ ${existing ? '更新' : '新建'}: ${slug}`);
    }

    if (hasChanges) {
      await triggerNotionNextDeploy();
    }

    lastSync = new Date().toISOString();
    fs.writeFileSync(lastSyncPath, lastSync);
  } catch (err) {
    console.error(`[${new Date().toLocaleTimeString()}] ❌`, err.message);
  }
}

setInterval(poll, 10000);
poll();
console.log('🚀 VPS 同步启动：10 秒轮询');
