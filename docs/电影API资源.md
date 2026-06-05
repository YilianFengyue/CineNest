这是一份为你整理好的**影视 API 免费资源库与使用文档**。你可以直接把它复制到你的项目的 `README.md` 中，或者作为你开发 Flutter 播放器时的参考手册。

---

# 🎬 影视聚合 API 免费资源库与接口规范文档

本文档整理了目前收录的 20 个免费影视 API 资源站，并提供了标准的 MacCMS v10 接口调用规范，帮助开发者快速实现影视内容的搜索、详情获取与视频播放。

## 📦 一、 免费资源接口列表

以下数据源均支持标准 MacCMS（苹果 CMS） JSON 接口协议：

| 资源站名称 | 接口地址 (API Endpoint) |
| --- | --- |
| **无尽资源** | `https://api.wujinapi.me/api.php/provide/vod` |
| **最大资源** | `https://api.zuidapi.com/api.php/provide/vod` |
| **极速资源** | `https://jszyapi.com/api.php/provide/vod` |
| **黑木耳** | `https://json.heimuer.xyz/api.php/provide/vod` |
| **电影天堂资源** | `http://caiji.dyttzyapi.com/api.php/provide/vod` |
| **如意资源** | `http://cj.rycjapi.com/api.php/provide/vod` |
| **暴风资源** | `https://bfzyapi.com/api.php/provide/vod` |
| **天涯资源** | `https://tyyszy.com/api.php/provide/vod` |
| **非凡影视** | `http://ffzy5.tv/api.php/provide/vod` |
| **360资源** | `https://360zy.com/api.php/provide/vod` |
| **茅台资源** | `https://caiji.maotaizy.cc/api.php/provide/vod` |
| **卧龙资源** | `https://wolongzyw.com/api.php/provide/vod` |
| **豆瓣资源** | `https://dbzy.tv/api.php/provide/vod` |
| **魔爪资源** | `https://mozhuazy.com/api.php/provide/vod` |
| **魔都资源** | `https://www.mdzyapi.com/api.php/provide/vod` |
| **樱花资源** | `https://m3u8.apiyhzy.com/api.php/provide/vod` |
| **旺旺短剧** | `https://wwzy.tv/api.php/provide/vod` |
| **iKun资源** | `https://ikunzyapi.com/api.php/provide/vod` |
| **量子资源站** | `https://cj.lziapi.com/api.php/provide/vod` |
| **小猫咪资源** | `https://zy.xmm.hk/api.php/provide/vod` |

*(注：免费资源站的域名可能会不定期失效或更换，建议在代码中做好异常捕捉和多源备用容灾处理。)*

---

## 🛠 二、 API 接口调用规范

所有接口采用标准的 `GET` 请求，支持返回 `JSON` 格式数据。

### 1. 搜索影片 (Search API)

用于根据关键字检索影片列表。

* **请求参数**: `?ac=videolist&wd={关键词}&pg={页码}`
* **示例**:
```http
GET https://api.wujinapi.me/api.php/provide/vod?ac=videolist&wd=阿凡达&pg=1

```


* **核心返回数据 (JSON)**:
```json
{
  "code": 1,
  "list": [
    {
      "vod_id": 12345,
      "vod_name": "阿凡达",
      "type_name": "科幻片",
      "vod_pic": "https://.../pic.jpg",
      "vod_remarks": "HD中字"
    }
  ]
}

```


*(💡 关键步骤：提取出列表中的 `vod_id` 用于下一步请求)*

### 2. 获取影片详情与播放链接 (Detail API)

获取视频的详情信息及包含 `.m3u8` 视频流的播放地址。

* **请求参数**: `?ac=detail&ids={视频ID}` (注意这里参数是 `ac=detail` 或者是部分站点的 `?ac=videolist&ids=`)
* **示例**:
```http
GET https://api.wujinapi.me/api.php/provide/vod?ac=detail&ids=12345

```


* **核心返回数据 (JSON)**:
```json
{
  "list": [
    {
      "vod_id": 12345,
      "vod_name": "阿凡达",
      "vod_content": "故事发生在2154年...",
      "vod_play_from": "wujinm3u8",
      "vod_play_url": "HD高清$https://v6.wujinm3u8.com/20240210/xxxx/index.m3u8#第2部分$https://..."
    }
  ]
}

```



---

## 💻 三、 数据解析与视频播放

### 1. 播放链接解析规则

API 返回的 `vod_play_url` 是一串由特殊符号拼接的字符串：

* `$`：用于分割【剧集名称】和【视频真实链接】。
* `#`：用于分割【不同的集数】或【不同的分段】。

**前端解析伪代码：**

```javascript
const rawUrl = "第01集$http://.../1.m3u8#第02集$http://.../2.m3u8";
const episodes = rawUrl.split('#'); // 按集数拆分

const playList = episodes.map(ep => {
  const [name, url] = ep.split('$'); // 拆分集名和链接
  return { title: name, playUrl: url };
});
// 结果: [{title: "第01集", playUrl: "http..."}, ...]

```

### 2. 播放器选型建议

拿到纯净的 `.m3u8` 链接后，普通的 MP4 播放器无法直接播放。

* **Flutter 端**：强烈推荐使用 `media_kit` 包（基于 libmpv），完美支持 m3u8 硬解码、无视跨域与各类不规范的切片。
* **Web (H5) 端**：需使用如 `hls.js`、`ArtPlayer` 或 `DPlayer` 等支持 HLS 协议的开源播放器。

---

## ⚠️ 四、 开发注意事项

1. **防盗链绕过**：部分资源站在请求时必须携带特定的请求头，如 `User-Agent`，可以在全局的网络拦截器中配置（参考原 `MoonTV` 中的搜索伪装请求头）。
2. **多源并发**：建议使用并发请求（如 `Promise.all` 或 Flutter 中的 `Future.wait`）同时检索多个接口，以提升搜索速度并聚合更全的资源。
3. **内容过滤**：资源库可能包含不符合规定的广告或片源（例如福利视频），建议开发时实装 `keyword` 关键词过滤器，屏蔽不良分类。