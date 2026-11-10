import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        for nome, h in [('avatar',1080),('p1',1350),('p2',1350),('p3',1350),('p4',1350),('p5',1350),('p6',1350)]:
            pg = await b.new_page(viewport={'width':1080,'height':h})
            await pg.goto(f'file:///home/claude/porquinho-repo/criativos/perfil.html?p={nome}'); await pg.wait_for_timeout(300)
            await pg.locator('.peca').screenshot(path=f'/home/claude/porquinho-repo/criativos/perfil/{nome}.png')
        await b.close()
asyncio.run(main())
