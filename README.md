# Faculty Atlas · 教授电子档案

为学校 HR 制作的中英文字段网站。前端可托管 GitHub Pages；Supabase 提供团队登录、共享数据库与私有附件。

## 当前交付状态

- 已实现：A–Z 排序与字母筛选；中文、英文和拼音搜索；院系／任职状态筛选；三种模板；档案新建编辑；自定义文字、长文本、日期、数字、下拉字段；PDF／图片附件；个人账号密码登录接入；只读／编辑角色；30 秒同步与手动同步；版本冲突提示；数据库修改记录。
- 演示模式：六条虚构档案，修改及附件仅保留在当前页面，刷新后清空，不会写入正式数据库。
- 尚未接通：没有提供 Supabase 项目 URL、公钥或测试账号，真实登录、数据库权限、云端附件及双账号并发尚未在远端验证。
- GitHub 仓库：`ZhichenGu/FacultyAtlas`。已补充兼容分支发布的根目录入口；正式档案登录仍需配置 Supabase。

## 本机体验

在此文件夹内运行：

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory dist
```

浏览器打开 http://127.0.0.1:4173，选择“打开演示档案”。无需安装 npm 依赖。正式部署请使用 HTTPS。不要双击 HTML 后将 file:// 当成正式运行方式。

## 三种模板

| 模板 | 可填写内容 |
|---|---|
| 通用教授档案 | 中英文姓名、拼音排序名、工号、院系、职称、任职状态、国籍、联系方式、聘期、教育、工作经历、材料来源及备注 |
| 教学科研档案 | 通用人事信息，另含研究方向、课程与学生指导、论文成果、科研项目、奖项 |
| 国际／访问学者档案 | 通用人事信息，另含原属机构、接待联系人、访问起止日期、工作许可／签证有效期、工作语言与访问目的 |

“＋添加字段”用于当前档案新增内容，不是自动生成任意软件功能。审批流程、OCR 等新业务功能仍需后续开发。自定义字段保存在档案中，其他授权 HR 可以共同查看和编辑。字段不会自动变为所有档案的全局模板。

排序按单独的 `sortName` 字段：张明远填 `Zhang Mingyuan`，James Wilson 填 `Wilson James`。明确排序名可处理多音字、复姓以及英文姓氏规则，不自动猜测身份信息。

## 正式接入：一次性设置

### 1. Supabase 数据库

1. 由学校管理员在 Supabase 创建项目。项目地区及服务使用由学校决定。
2. 在新项目的 SQL Editor 执行 `database/setup.sql` 一次。脚本在事务中建表、打开行级权限、创建私有附件桶。已有同名表时不要直接重复运行，先核对现状。
3. 在 Authentication 设置中关闭公开注册。通过后台创建 HR 用户，并由用户自行设置密码；前端没有公开注册入口。
4. 创建用户后，在 SQL Editor 授予明确成员权限；把示例邮箱替换为实际 HR 账号：

```sql
insert into public.hr_members(user_id, role)
select id, 'editor' from auth.users where email = 'hr@example.edu';
-- 只读成员将 editor 改为 viewer。没有名单的账号无法读取任何档案。
```

5. 编辑 `dist/config.js`：

```js
window.FACULTY_CONFIG = {
  supabaseUrl: 'https://YOUR-PROJECT.supabase.co',
  supabaseKey: 'YOUR-PUBLISHABLE-OR-ANON-KEY'
};
```

公钥可以在前端出现；**不能填写 `service_role`、`sb_secret_` 或个人密码**。访问保护来自数据库与存储策略，不来自隐藏公钥。该版本接受标准 supabase.co 项目域名，自定义域名需要调整配置校验。

### 2. GitHub Pages

当前仓库使用 **Deploy from a branch → main → / (root)** 发布。

1. 在仓库 Settings → Pages 中确认 Source 为 **Deploy from a branch**，分支为 **main**，目录为 **/ (root)**。
2. 用 GitHub Desktop 提交更改并点击 **Push origin**。
3. 等待 GitHub 的 `pages build and deployment` 完成后，访问 https://zhichengu.github.io/FacultyAtlas/ 。

根目录 `index.html` 会自动进入 `dist/` 中的网站；`.nojekyll` 让 Pages 按静态文件发布。请保留这两个文件，避免再次把 README 当首页。

`dist/` 中是网页文件，数据库仍需按上面的 Supabase 步骤接入。先前交付包的自定义 `.github/workflows/pages.yml` 未复制进此仓库；当前分支发布方式不需要它。不要混用两种部署来源。

GitHub Pages 只托管网页，真实档案经 HTTPS 访问 Supabase。每位 HR 使用独立邮箱和密码。

### 3. 正式使用前的远端验收

使用虚构测试记录，不放真实资料进行首轮验证。

- 未登录以及已注册但未列入 hr_members 的账号：数据库和附件 API 必须拒绝读取／写入。
- viewer：能查看和下载，不能新增、改档案、上传附件或维护成员权限。
- editor：能创建／编辑、上传 PDF 和图片；退出后看不到档案。
- 两位 editor 同时打开同一档案：第一人保存后，第二人保存必须提示冲突且保留表单，不覆盖新版本；复制修改后同步再编辑。
- 两个浏览器登录：一个保存，另一个手动同步或等待 30 秒能看到修改。
- 上传超过 10 MB 或非允许文件类型，服务端也应拒绝。
- 取消成员资格后重新请求 API，应立即失去权限；已经下载到本机的数据无法远程撤回。

## 使用边界与维护

- 这是单个学校团队的共享档案库，所有获准成员可读全库；不是院系分区权限或多租户产品。
- 登录令牌仅存内存，刷新页面需重新登录；没有把密码、资料或令牌放入 localStorage。已打开页面中的会话会在请求前刷新。
- 前端依赖 Supabase 在线服务。网络错误会显示失败，保存成功才关闭表单；不会假装离线保存成功。
- 档案修改有版本号，审计表记录操作者／时间／操作／版本，不是全文历史恢复系统。HR 可将离职人员标记“已离职”，本版不提供永久删除入口。
- 私有附件下载通过认证请求；上传成功但元数据写入中断可能留下未列出的文件，管理员需核查。未实现文件病毒扫描和 OCR。
- 管理员按学校档案政策备份 Supabase 数据库与 Storage；数据库备份不等于附件备份。请在正式投入使用前配置备份周期并验证恢复。
- 当前列表每次加载全部授权档案（按 1000 条分页读取以避开默认返回上限）；适合常规校级目录。资料规模明显增大时再改为服务端搜索与分页。
- 本项目的“为 GPT-6 Astra 优化”体现在结构化字段、独立材料来源、可读文件与简洁 AGENTS.md，以及支持浏览器时提供目录搜索工具。未接入模型 API，也不会自动发送教授资料给模型。
- WebMCP 目录搜索是可选增强，普通浏览器不支持也可正常使用。

本地回归检查：`node tests/smoke.cjs`（不访问网络，不需要账号）。

## 文件位置

- `dist/index.html`：登录与目录、模板、档案表单。
- `dist/app.js`：交互、字段定义、Supabase REST 与可选页面工具。
- `dist/style.css`：桌面和手机样式。
- `dist/config.js`：项目 URL、公钥。
- `database/setup.sql`：数据库、权限、私有存储。
- `index.html` 与 `.nojekyll`：GitHub Pages 根目录入口与静态发布标记。
- `AGENTS.md`：后续模型协作规则。
- `规则审查.md`：规则风险、处理方法与依据。
- `验证记录.md`：本次实际检查与待验收项。

## 参考

- [GitHub Pages 静态托管说明](https://docs.github.com/en/pages/getting-started-with-github-pages/what-is-github-pages)
- [GitHub Pages 发布方法](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site)
- [Supabase 密码登录](https://supabase.com/docs/guides/auth/passwords)
- [Supabase 行级权限](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase 私有附件访问控制](https://supabase.com/docs/guides/storage/security/access-control)
