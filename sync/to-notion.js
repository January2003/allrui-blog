const { Client } = require('@notionhq/client');
const { markdownToBlocks } = require('@tryfabric/martian');
const matter = require('gray-matter');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const dbId = process.env.NOTION_DATABASE_ID;
const mappingPath = path.join(__dirname, 'notion-mapping.json');

let mapping = {};
if (fs.existsSync(mappingPath)) {
  mapping = JSON.parse(fs.readFileSync(mappingPath, 'utf8'));
}

function getChangedFiles() {
  try {
    const output = execSync('git diff --name-only HEAD~1 HEAD', { encoding: 'utf8' });
    return output.split('\n').filter(f => f.startsWith('content/') && f.endsWith('.md'));
  } catch {
    return fs.readdirSync(path.join(__dirname, '../content'))
      .filter(f => f.endsWith('.md'))
      .map(f => `content/${f}`);
  }
}

async function appendBlocks(pageId, blocks) {
  const chunkSize = 100;
  for (let i = 0; i < blocks.length; i += chunkSize) {
    await notion.blocks.children.append({ block_id: pageId, children: blocks.slice(i, i + chunkSize) });
  }
}

async function clearBlocks(pageId) {
  const existing = await notion.blocks.children.list({ block_id: pageId });
  for (const block of existing.results) {
    await notion.blocks.delete({ block_id: block.id });
  }
}

async function syncFile(filePath) {
  const fullPath = path.join(__dirname, '..', filePath);

  if (!fs.existsSync(fullPath)) {
    if (mapping[filePath]) {
      await notion.pages.update({
        page_id: mapping[filePath],
        properties: { Status: { select: { name: 'Archived' } } }
      });
      console.log(`🗑️ 归档: ${filePath}`);
    }
    return;
  }

  const raw = fs.readFileSync(fullPath, 'utf8');
  const parsed = matter(raw);
  const title = parsed.data.title || path.basename(filePath, '.md');
  const tags = (parsed.data.tags || []).map(t => ({ name: String(t) }));
  const date = parsed.data.date || new Date().toISOString().split('T')[0];
  const slug = parsed.data.slug || path.basename(filePath, '.md');
  const body = parsed.content;

  const blocks = markdownToBlocks(body, {
    notionLimits: { truncate: true },
    strictImageUrls: false
  });

  const pageId = mapping[filePath];

  if (pageId) {
    await notion.pages.update({
      page_id: pageId,
      properties: {
        Name: { title: [{ text: { content: title } }] },
        Tags: { multi_select: tags },
        Date: { date: { start: date } },
        Status: { select: { name: parsed.data.draft ? 'Draft' : 'Published' } },
        Slug: { rich_text: [{ text: { content: slug } }] }
      }
    });

    await clearBlocks(pageId);
    await appendBlocks(pageId, blocks);
    console.log(`✅ 更新: ${title}`);

  } else {
    const response = await notion.pages.create({
      parent: { database_id: dbId },
      properties: {
        Name: { title: [{ text: { content: title } }] },
        Tags: { multi_select: tags },
        Date: { date: { start: date } },
        Status: { select: { name: 'Published' } },
        Slug: { rich_text: [{ text: { content: slug } }] }
      },
      children: blocks.slice(0, 100)
    });

    if (blocks.length > 100) await appendBlocks(response.id, blocks.slice(100));
    mapping[filePath] = response.id;
    console.log(`🆕 创建: ${title}`);
  }
}

(async () => {
  const files = getChangedFiles();
  console.log(`📄 变更: ${files.length} 个文件`);
  for (const file of files) {
    try { await syncFile(file); }
    catch (err) { console.error(`❌ ${file}:`, err.message); process.exitCode = 1; }
  }
  fs.writeFileSync(mappingPath, JSON.stringify(mapping, null, 2));
})();
