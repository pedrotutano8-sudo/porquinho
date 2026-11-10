import asyncio, subprocess, sys, os
from playwright.async_api import async_playwright
BASE='/home/claude/porquinho-repo/criativos'
NOMES={'1':'V1-conta-vira-credito','2':'V2-golpe','3':'V3-tres-itens'}
async def main(previa):
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/usr/bin/google-chrome', args=['--no-sandbox'])
        pg = await b.new_page(viewport={'width':1080,'height':1920})
        for v, nome in NOMES.items():
            await pg.goto(f'file://{BASE}/video.html?v={v}'); await pg.wait_for_timeout(400)
            dur = await pg.evaluate('window.DUR')
            if previa:
                for t in previa.get(v, []):
                    await pg.evaluate(f'render({t})'); await pg.screenshot(path=f'/tmp/pv/{v}-{t}.jpg', type='jpeg', quality=80)
                continue
            tmp=f'{BASE}/videos/{nome}.tmp.mp4'
            ff = subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','image2pipe','-framerate','30','-c:v','mjpeg','-i','-','-c:v','libx264','-crf','18','-preset','veryfast','-pix_fmt','yuv420p','-movflags','+faststart',tmp], stdin=subprocess.PIPE)
            for i in range(int(dur*30)):
                await pg.evaluate(f'render({i/30})')
                ff.stdin.write(await pg.screenshot(type='jpeg', quality=92))
            ff.stdin.close()
            if ff.wait()==0: os.replace(tmp, f'{BASE}/videos/{nome}.mp4')
        await b.close()
previa = {'1':[3.2,7.5,12,15.5],'2':[3.2,5.8,10.5],'3':[3,9]} if len(sys.argv)>1 else None
asyncio.run(main(previa))
