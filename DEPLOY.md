# 发布上线指南（DEPLOY）

> 本站是**纯静态站点**：没有构建步骤、没有后端、不依赖任何外部 CDN 或字体。
> 也就是说 —— **整个文件夹原样传上去就能用**，不需要 `npm install`，也不需要填写「构建命令」。

发布前我先帮你做好的准备（这些文件已经在项目里）：

| 文件 | 作用 |
| --- | --- |
| `.gitignore` | 忽略系统垃圾 / 编辑器目录（GitHub 上传时不会混进无关文件） |
| `_headers` | 缓存与安全响应头（Cloudflare Pages / Netlify 自动读取，GitHub Pages 忽略） |
| `404.html` | 自定义错误页（三个平台都自动识别根目录的 404.html） |
| `.nojekyll` | 让 GitHub Pages 跳过 Jekyll 处理，原样发布文件 |
| `.git`（已初始化并提交） | 已经做好第一次提交，推到 GitHub 只需 2 条命令 |

---

## 零、先在本地确认一遍

双击 `index.html` 就能看。想更接近线上环境，任选一种起本地服务器：

```powershell
# 方式一：Python（你本机已装 3.14.3）
cd "c:\Users\27911\Desktop\学习\AI辅助软件开发\my-website"
python -m http.server 5173

# 方式二：Node（你本机已装 v24.20.0）
npx --yes serve -l 5173 .
```

然后浏览器打开 <http://127.0.0.1:5173>，重点看：首屏大图、44 张缩略图、筛选按钮、点开大图（灯箱）、把窗口拉窄到手机尺寸的排版。

> ⚠️ 直接双击 `index.html`（`file://` 协议）也能看，但那种方式下浏览器对本地文件的安全策略更严，
> 所以**以 `http://` 方式看到的效果才是线上的真实效果**。

---

## 一、最省事：拖拽上传（约 5 分钟，不用写命令）

### 方案 A：Cloudflare Pages（推荐，免费、免备案、全球节点）

1. 打开 <https://dash.cloudflare.com/sign-up> 用邮箱注册并登录（免费）。
2. 左侧菜单 **Workers & Pages** → **Create** → 切到 **Pages** 标签 → 选 **Upload assets**。
3. **Project name** 填 `lumina-photo`（这将成为你的网址前缀）。
4. 把 **`my-website` 这个文件夹整个拖进去**（拖文件夹本身，不要只拖里面的文件）。
5. 点 **Deploy site**，几十秒后得到网址，形如 `https://lumina-photo.pages.dev`。
6. 以后想用**自己的域名**：进入该项目 → **Custom domains** → 添加域名（域名的 DNS 建议也托管在 Cloudflare，最省事）。

> 特点：免费额度很宽裕；改版重新拖一次即可覆盖；`_headers`、`404.html` 都自动生效。

### 方案 B：Netlify Drop（最快，不用注册也能先看效果）

1. 打开 <https://app.netlify.com/drop>。
2. 把 `my-website` 文件夹拖进去 → 立刻得到 `https://随机名.netlify.app`。
3. 想长期保留：点 **Sign up** 绑定账号（同样免费）；站名可在 **Site configuration → Change site name** 改。

---

## 二、正规做法：Git 仓库 + 自动部署（推荐长期维护）

好处：以后改了照片或文字，`git push` 一次，网站自动更新；也有版本记录，改坏了能回退。

### 2.1 推到 GitHub

1. 登录 <https://github.com> → 右上角 **+** → **New repository**。
2. 仓库名填 `lumina-photo`，可见性选 **Public**，**不要**勾选 “Add a README / .gitignore / license”（我们已经有了）。
3. 在本项目文件夹打开终端（VS Code 里 `Ctrl + ~`），执行：

```powershell
git remote add origin https://github.com/你的用户名/lumina-photo.git
git push -u origin main
```

4. 第一次推送会弹出浏览器，让你登录并授权 GitHub（Git Credential Manager），点同意即可。
5. 回到仓库页面 → **Settings** → 左侧 **Pages** → **Source** 选 **Deploy from a branch**，
   **Branch** 选 `main` + **/(root)** → **Save**。
6. 等 1～2 分钟，网址是 `https://你的用户名.github.io/lumina-photo/`。

> **本次的实际部署目标**：仓库 <https://github.com/250466216/-website>（Public，已配置为 remote `origin`），
> 站点地址将是 `https://250466216.github.io/-website/`。
> 因为这是**子目录地址**，`404.html` 末尾的 `SITE_BASE` 已设为 `'/-website/'`
> （只改这一处，页内所有链接自动补前缀）。
>
> 如果想直接得到 `https://用户名.github.io/`：仓库名必须**正好等于** `用户名.github.io`，
> 那时把 `SITE_BASE` 改回 `''` 即可。

### 2.2 或者：Cloudflare Pages 连仓库（同样免费，国内相对更快）

1. Cloudflare → **Workers & Pages** → **Create** → **Pages** → **Connect to Git**。
2. 授权 GitHub，选中刚建的仓库。
3. 关键设置：
   - **Build command（构建命令）：留空**
   - **Build output directory（输出目录）：填 `/`**
4. **Save and Deploy** → 得到 `https://lumina-photo.pages.dev`。之后每次 `git push` 都会自动重新发布。

### 2.3 已经推过一次仓库后，日常更新三步

```powershell
git add -A
git commit -m "update photos"
git push
```

---

## 三、以后加了新照片，怎么重新发布

```powershell
# 1) 把新照片丢进 C:\Users\27911\Desktop\资料\摄影\压缩

# 2) 编辑映射表（UTF-8 文本，每行：分类键 | 显示名 | 作品名 | 源文件名）
notepad "$env:TEMP\lumina-map.txt"

# 3) 重跑导入脚本（自动旋转、压缩、读 EXIF、重写 js/gallery-data.js）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\import-photos.ps1 `
  -MapFile "$env:TEMP\lumina-map.txt" `
  -SourceFolderFile "$env:TEMP\lumina-folder.txt" `
  -HeroSource 'IMG_20260202_191822.jpg' `
  -AboutSource 'IMG_20260914_103946.jpg'

# 4) 发布
git add -A; git commit -m "add new photos"; git push
#    如果是拖拽上传的托管方式：重新把整个文件夹拖一次即可覆盖
```

> 分类数量请保持 **4 的倍数**（桌面 4 列、窄屏 2 列都刚好填满整行），否则最后一行会显得突兀。
> 详细说明见 `README.md` 第三节。

---

## 四、国内访问速度：说句实话

| 托管方式 | 稳定性 | 国内访问速度 | 花费 | 备案 |
| --- | --- | --- | --- | --- |
| Cloudflare Pages（`*.pages.dev`） | 高 | 一般（境外节点，晚高峰更慢） | 免费 | 不需要 |
| Netlify（`*.netlify.app`） | 高 | 一般～偏慢 | 免费 | 不需要 |
| GitHub Pages（`*.github.io`） | 中（偶尔被墙） | 慢 | 免费 | 不需要 |
| 腾讯云 COS / 阿里云 OSS + CDN | 很高 | **快** | 几元/月（按流量） | **必须备案** |

- 想让国内访问稳定又快，只有一条路：**买域名 + ICP 备案**（个人备案一般 1～2 周），
  然后把整个文件夹上传到国内对象存储并开启静态网站托管 + CDN。
- 折中方案：**先免费用 Cloudflare Pages 上线**，以后需要了再买域名绑上去（备案是绑域名时才需要的）。
- 成本提示：`images/` 里 44 张大图约 12MB，对象存储按流量计费，普通个人站的费用通常是每月几毛到几元。

---

## 五、上线前请务必确认这 3 件事

1. **QQ 号会公开在互联网上**（`2791187784`，`index.html` 第 147～153 行的 `.contact-list`）。
   QQ 号会被搜索引擎收录，也可能招来陌生好友申请。这比公开手机号安全得多，
   但如果想更隐蔽，可以把号码拆开写（`2791 187 784`，能挡住一部分机器抓取），或只保留联系表单。
2. **联系表单目前是纯前端演示**（`index.html` 的 `.form-hint` 已注明），提交不会真的发出去。
   想让留言真的送到你手里：接一个免费表单服务（如 Formspree 表单接口），或把按钮改成跳转 QQ 会话。
3. **照片版权声明**：页脚已写「站内照片均为本人拍摄，未经许可请勿转载」。
   如果以后要做商业授权，建议再加一行「Contact for licensing」。

---

## 六、常见问题

**照片/样式不显示？**
路径全部是相对路径，必须保持 `index.html` 与 `images/`、`css/`、`js/` 同级。
不要只把 `index.html` 单独拿出来上传。

**换了照片但网页还是旧的？**
① 先 `Ctrl + F5` 强刷；② 图片缓存是 7 天（见 `_headers`），
想立刻全网生效：Cloudflare 后台 → **Caching → Purge Everything**，或把文件名换一个（如 `work-45.jpg`）。

**部署在子目录时有点问题？**
GitHub Pages 的项目页地址是 `https://用户名.github.io/仓库名/`，这时把 `404.html` 末尾的
`var SITE_BASE = '';` 改成 `var SITE_BASE = '/仓库名/';` 即可（中文仓库名填浏览器地址栏里那串百分号编码）。
其余文件都是相对路径，无需改动。

**能加自己的域名吗？**
可以。Cloudflare Pages：**Custom domains → Add**；GitHub Pages：在仓库的 Pages 设置里填 Custom domain，
然后到域名商处加一条 CNAME 指向你的站点地址。

**换模型/换电脑后还能继续维护吗？**
能。所有素材处理逻辑都在 `scripts/import-photos.ps1`，只需 Windows + PowerShell 5.1，不需要任何第三方依赖。
