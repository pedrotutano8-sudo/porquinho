import asyncio
from playwright.async_api import async_playwright
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        for f, h in [('feed', 1350), ('story', 1920)]:
            pg = await b.new_page(viewport={'width': 1080, 'height': h})
            for c, nome in [('A', 'conta-de-luz'), ('B', 'checklist'), ('C', 'fatura-exemplo'), ('D', 'whatsapp')]:
                await pg.goto(f'file:///home/claude/porquinho-repo/criativos/criativos.html?c={c}&f={f}'); await pg.wait_for_timeout(300)
                await pg.locator('.peca').screenshot(path=f'/home/claude/porquinho-repo/criativos/{c}-{nome}-{f}.png')
        await b.close()
asyncio.run(main())
