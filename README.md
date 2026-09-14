# 光影志 LUMINA · 个人摄影作品集网站

一个**纯静态**的个人摄影作品网站：不依赖任何框架、不用安装依赖、不用编译，双击 `index.html` 就能看。
深色底 + 暖金色点缀，现收录 **44 张本人拍摄的作品**，按 **风光 / 动物 / 建筑 / 街拍 / 花草** 五个题材分类。

> 站内照片均导入自 `Desktop\资料\摄影\压缩`（原始素材），作品名按画面内容拟定；
> 年份、光圈 / 快门 / ISO 由脚本从照片原始 EXIF 自动读取，未加修饰。
> 拍摄地点字段目前留空，需要时在 `js/gallery-data.js` 里补一行 `place: '拍摄地'` 就会显示。
> 想换图 / 加图：改好映射表后重跑 `scripts/import-photos.ps1`，见第三、六节。
> 要发布上线：见 [`DEPLOY.md`](DEPLOY.md) —— 纯静态、零依赖，仓库已初始化，可直接推 GitHub 或拖拽上传。

---

## 一、快速预览

方式 1（最简单）：直接双击 `index.html`。

方式 2（推荐，行为与线上一致）：在本目录打开终端，启动一个本地静态服务器。

```powershell
# 有 Python
python -m http.server 5173

# 或者有 Node.js
npx --yes serve -l 5173
```

然后浏览器访问 <http://localhost:5173>。

---

## 二、目录结构

```
my-website/
├─ index.html                       # 页面结构（导航 / 首屏 / 作品集 / 关于 / 联系 / 页脚 / 灯箱）
├─ 404.html                         # 自定义错误页（完全自包含，样式内联，不依赖 style.css）
├─ css/
│  └─ style.css                     # 全部样式，顶部有目录索引
├─ js/
│  ├─ gallery-data.js               # ★ 作品数据（图片路径、标题、分类、地点、年份、器材）
│  └─ main.js                       # 交互逻辑（渲染、筛选、灯箱、导航、动画、表单校验）
├─ images/                          # 图片目录（全部为本人作品，已统一压缩）
│  ├─ hero.jpg                      # 首屏大图（长边 1920px）
│  ├─ about.jpg                     # 「关于我」配图（长边 1100px 竖图）
│  ├─ work-01.jpg ~ work-44.jpg     # 作品大图（灯箱里显示，平均 281KB）
│  └─ thumbs/work-01.jpg ~ 44.jpg   # 网格缩略图（长边 900px，平均 108KB，首屏更快）
├─ scripts/
│  └─ import-photos.ps1             # ★ 批量导入 / 压缩 / 自动生成作品数据的脚本
├─ DEPLOY.md                        # ★ 发布上线指南（拖拽上传 / Git 自动部署 / 国内访问说明）
├─ _headers                         # 缓存与安全响应头（Cloudflare Pages / Netlify 自动读取）
├─ .nojekyll                        # 让 GitHub Pages 跳过 Jekyll 处理
├─ .gitignore                       # Git 忽略规则（仓库已 init 并完成首次提交）
└─ README.md
```

---

## 三、日常维护：改文字 / 换图 / 加图

### 只改文字：编辑 `js/gallery-data.js`

```js
window.PHOTOS = [
  {
    src: 'images/work-01.jpg',          // 灯箱里显示的大图（长边 1400px）
    thumb: 'images/thumbs/work-01.jpg', // 网格里的缩略图（长边 900px）
    title: '霞映湖城',                   // 作品名（必填）
    category: 'landscape',              // 分类键（必填，见下表）
    year: '2025',                       // 年份（选填，留空则不显示）
    camera: 'OPPO Reno13 · f/2.2 · 1/1957s · ISO 50'   // 器材参数（选填，只在灯箱显示）
    // place: '拍摄地点，例如 上海 · 滨江',   // 选填，加上就会出现在遮罩与灯箱里
  },
  // …顺序就是页面展示顺序
];
```

分类对照表：

| 分类键 | 显示名 | 当前作品数 |
| --- | --- | --- |
| `landscape` | 风光 | 20 |
| `animal` | 动物 | 8 |
| `architecture` | 建筑 | 8 |
| `street` | 街拍 | 4 |
| `plant` | 花草 | 4 |

> **版式很关键的一点**：作品网格是**固定列数** —— 桌面 4 列、窄屏 2 列。
> 请让**每个分类**的作品数量保持为 **4 的倍数**（自然也是 2 的倍数），这样每一行都刚好填满，
> 不会出现「最后一行孤零零只剩一张、凸出来一块」的情况。
> 目前共 44 张：风光 20 + 动物 8 + 建筑 8 + 街拍 4 + 花草 4，全部满足。
> 万一将来数量除不尽，`js/main.js` 里的兜底逻辑会自动把最后一张拉满整行。

- 想**新增分类**：在 `window.PHOTO_CATEGORIES` 里加一行，例如
  `wildlife: '野生动物'`，再到 `index.html` 的筛选按钮区加一个
  `<button class="filter-btn" data-filter="wildlife" type="button">野生动物 <span class="filter-count" data-count="wildlife">0</span></button>`
  （数字会自动统计，不用手填）。
- 想让某个分类**不显示**：删掉对应的筛选按钮即可，作品数据可以保留。

### 批量换图 / 加图：重跑导入脚本

1. 把新照片放进一个文件夹（也可以继续用 `Desktop\资料\摄影\压缩`）。
2. 准备映射表（UTF-8 文本，每行 `分类键 | 显示名 | 作品名 | 源文件名`）：

```
landscape | 风光 | 霞映湖城 | IMG_20251110_170410.jpg
animal | 动物 | 碧水双鹅 | 2026-01-08-天鹅.jpg
```

3. 在项目根目录执行（自动旋转、压缩、读 EXIF、重写 `js/gallery-data.js`）：

```powershell
# 照片夹路径写进一个 UTF-8 文本文件（只有一行路径），中文路径更稳
Set-Content -Path "$env:TEMP\lumina-folder.txt" -Value 'C:\Users\你\Desktop\资料\摄影\压缩' -Encoding utf8

powershell -ExecutionPolicy Bypass -File .\scripts\import-photos.ps1 `
  -MapFile "$env:TEMP\lumina-map.txt" `
  -SourceFolderFile "$env:TEMP\lumina-folder.txt" `
  -HeroSource 'IMG_20260202_191822.jpg' `
  -AboutSource 'IMG_20260914_103946.jpg'
```

> 也可以直接把文件夹路径写在命令行里：`-SourceFolder "C:\...\压缩"`；
> 省略 `-ProjectRoot` 时脚本自动使用自己所在目录的上一级（即站点根目录）。
> 脚本细节见第六节。

---

## 四、功能说明

| 功能 | 说明 |
| --- | --- |
| 响应式布局 | 手机 / 平板 / 桌面三档断点，导航在窄屏折叠成汉堡菜单 |
| 分类筛选 | 「全部 / 风光 / 动物 / 建筑 / 街拍 / 花草」，每个按钮实时显示该分类作品数量（数据一变自动更新） |
| 缩略图 + 懒加载 | 网格加载 900px 缩略图（`thumb`），点开才下载 1400px 大图（`src`）；44 张作品首屏依然很轻 |
| 大图灯箱 | 点击作品放大：全屏黑色 90% 遮罩（`z-index: 2000`）+ 居中，**0.3s 淡入淡出**；`←` `→` 切换、`Esc` 关闭、点遮罩关闭；手机可左右滑动；自动预加载前后一张 |
| 首屏视差 | 背景图缓慢推近 + 渐显文字，`Scroll` 指示条 |
| 滚动动画 | 内容进入视口淡入上移，统计数字滚动到目标值 |
| 联系表单 | 姓名 / 邮箱 / 留言必填校验，错误高亮提示（纯前端演示，**没有后端**） |
| 无障碍 | 语义化标签、`aria-*` 属性、键盘可操作、`:focus-visible` 焦点样式、`prefers-reduced-motion` 降级 |
| 打印样式 | 打印时自动隐藏导航、灯箱、筛选等交互元素 |

浏览器兼容：Chrome / Edge / Firefox / Safari 近两年的版本；未使用任何第三方库。

---

## 五、常见自定义

| 想改什么 | 改哪里 |
| --- | --- |
| 主色（现在是暖金 `#d9a866`） | `css/style.css` 顶部的 `--accent` |
| 背景深浅 | `css/style.css` 顶部的 `--bg` / `--bg-soft` / `--bg-card` |
| 站点名与 Logo 文字 | `index.html` 里 `.brand` 区块，以及 `<title>`、页脚 |
| 首屏标题 / 自我介绍 | `index.html` 里 `.hero-title`、`.hero-sub` |
| 关于我文案、统计数字、器材清单 | `index.html` 里 `#about` 区块（数字改 `data-count-to`） |
| QQ 号 / 常驻地 | `index.html` 里 `#contact` 的 `.contact-list`（想变成「点击跳转加好友」，把 `<span>2791187784</span>` 换成 `<a href="https://wpa.qq.com/msgrd?v=3&uin=2791187784&site=qq&menu=yes">2791187784</a>`） |
| 作品每行格子数与高度 | `css/style.css` 里 `.gallery-grid` 的 `grid-template-columns`（列数）与 `grid-auto-rows`（行高） |
| 灯箱遮罩颜色 / 淡入淡出速度 | `css/style.css` 里 `.lightbox` 的 `background-color`、`transition`；**时长要和 `js/main.js` 的 `LIGHTBOX_FADE_MS` 一起改**（两边必须一致，否则淡出没结束就隐藏了） |
| 灯箱层级（被别的东西盖住时） | `css/style.css` 里 `.lightbox` 的 `z-index`（现在是 2000，导航是 100） |
| 缩略图 / 大图的尺寸与画质 | 重跑 `scripts/import-photos.ps1`，调 `-ThumbEdge` / `-FullEdge` / `-Quality` |
| 首屏大图、「关于我」配图 | 重跑脚本时用 `-HeroSource` / `-AboutSource` 换成别的照片 |

---

## 六、导入脚本 `scripts/import-photos.ps1` 做了什么

| 步骤 | 说明 |
| --- | --- |
| 1. 方向校正 | 读取 EXIF `Orientation`，竖拍照片不会被横过来 |
| 2. 压缩 | 长边 1400px → `images/work-NN.jpg`；长边 900px → `images/thumbs/work-NN.jpg`；JPEG 质量 82 |
| 3. 读 EXIF | 拍摄日期 → `year`；机型 + 光圈 + 快门 + ISO → `camera`（没有 EXIF 的照片这两项留空，页面自动不显示） |
| 4. 生成数据 | 按映射表顺序重写 `js/gallery-data.js`（UTF-8 无 BOM；分类键去重且保持出现顺序） |
| 5. 首屏与配图 | `-HeroSource` → 长边 1920px 的 `images/hero.jpg`；`-AboutSource` → 长边 1100px 的 `images/about.jpg` |
| 6. 报告 | 每张的结果写入 `%TEMP%\lumina-import-report.tsv`（源文件 / 分类 / 标题 / 年份 / 参数 / 输出尺寸） |

参数一览：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-MapFile` | 必填 | 映射表路径，UTF-8，每行 `分类键 \| 显示名 \| 作品名 \| 源文件名` |
| `-SourceFolder` / `-SourceFolderFile` | — | 照片文件夹；后者是只含一行路径的 UTF-8 文本文件（中文路径更稳） |
| `-ProjectRoot` | 脚本上一级目录 | 站点根目录 |
| `-FullEdge` / `-ThumbEdge` / `-Quality` | 1400 / 900 / 82 | 大图长边 / 缩略图长边 / JPEG 质量 |
| `-HeroSource` / `-AboutSource` | 空 | 用于生成首屏图、「关于我」配图的源文件名 |

脚本会跳过找不到的源文件并打印警告，最后输出 `imported = N   failed = M`。
重新执行会**覆盖** `images/work-NN.jpg` 与 `js/gallery-data.js`，请先确认映射表没写错。

> 脚本是 **ASCII-only** 的：变量、注释、提示都用英文，中文只出现在映射表与生成的数据文件里。
> 原因是 Windows PowerShell 5.1 会把「无 BOM 的 UTF-8 脚本」误判成 GBK，中文会变乱码并导致语法错误。

> **隐私**：脚本只重写像素与拍摄参数，**不会**把原始 GPS 定位写进新文件——
> 重新压缩后的图片里已经没有位置信息，发到网上更安全。

---

## 七、照片与版权

- `images/` 里的 44 张照片均为本人拍摄，页脚已写明「未经许可请勿转载」。
- 作品名是按画面内容拟的，如果某张想改名，直接在 `js/gallery-data.js` 里改 `title` 即可。
- 网站代码可以随意修改、删减、拿去做自己的项目。

---

## 八、部署上线

**完整步骤、平台对比、国内访问真相与常见问题见 [`DEPLOY.md`](DEPLOY.md)**，这里只给最短路径：

| 方式 | 需要什么 | 大约耗时 | 网址形如 |
| --- | --- | --- | --- |
| Cloudflare Pages（拖拽上传） | 一个免费账号 | 5 分钟 | `https://xxx.pages.dev` |
| Netlify Drop（拖拽，不注册也能先看） | 无 | 2 分钟 | `https://xxx.netlify.app` |
| GitHub Pages（推仓库 + 自动部署） | GitHub 账号 | 15 分钟 | `https://用户名.github.io/仓库名/` |
| 国内对象存储 + CDN | 域名 + ICP 备案 | 1～2 周 | 自己的域名（国内访问最快） |

- 本站是**纯静态**：没有构建命令、没有 npm 依赖、不引用任何外部 CDN 或字体，**把整个文件夹传上去就能跑**。
- 项目里的 Git 仓库**已初始化并完成首次提交**（分支 `main`），推到 GitHub 只需要两条命令：

```powershell
git remote add origin https://github.com/你的用户名/仓库名.git
git push -u origin main
```

- 已经准备好的发布文件：`404.html`（自定义错误页）、`_headers`（缓存 / 安全响应头）、`.nojekyll`（GitHub Pages 跳过 Jekyll）、`.gitignore`。
- ⚠️ **上线前注意隐私**：QQ 号会**公开在互联网上**（`index.html` 第 147～153 行的 `.contact-list`），
  QQ 号会被搜索引擎收录、也可能招来陌生好友申请。它比手机号安全得多，但如果你希望更隐蔽，
  可以把号码拆开写（如 `2791 187 784`）或只留联系表单。
- 联系表单目前是**纯前端演示**，不会真的把留言发到任何地方（页面上有提示）。
  想让留言真的送到你手里，可以接一个免费表单服务（如 Formspree），或把按钮改成跳转 QQ 会话。
- 部署在子目录时（如 GitHub Pages 项目页 `/仓库名/`），只需把 `404.html` 末尾那处配置改成
  `var SITE_BASE = '/仓库名/';`（**一处生效**，页内所有链接会自动加前缀）；其余文件都是相对路径，无需改动。

> `images/` 共 88 个文件（44 张大图 + 44 张缩略图）约 17MB，第一次上传稍慢是正常的；
> 之后改内容只需重新上传变动的文件（或 `git push`）。
