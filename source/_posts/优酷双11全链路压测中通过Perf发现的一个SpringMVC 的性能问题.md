---
title: 双11全链路压测中通过Perf发现的一个SpringMVC 的性能问题
date: 2018-07-26 16:30:03
categories: troubleshooting
tags:
    - Linux
    - performance
    - troubleshooting
    - perf
    - SpringMVC
---
# 双11全链路压测中通过Perf发现的一个SpringMVC 的性能问题

> 在最近的全链路压测中TPS不够理想，然后通过perf 工具（perf record 采样， perf report 展示）看到(可以点击看大图)：


![screenshot](/images/oss/b5610fa7e994b1e4578d38347a1478a7)


## 再来看CPU消耗的火焰图：

![screenshot](/images/oss/d228b47200f56fbbf5aadf0da56cbf15)

图中CPU的消耗占21%，不太正常。

> 可以看到Spring框架消耗了比较多的CPU，具体原因就是在Spring MVC中会大量使用到 
@RequestMapping
@PathVariable
带来使用上的便利

## 业务方修改代码去掉spring中的methodMapping解析后的结果（性能提升了40%）：
![screenshot.png](/images/oss/a97e6f1da93173055b1385eebba8e327.png)

图中核心业务逻辑能抢到的cpu是21%（之前是15%）。spring methodMapping相关的也在火焰图中找不到了


### Spring收到请求URL后要取出请求变量和做业务运算，具体代码(对照第一个图的调用堆栈）：

```
170	public RequestMappingInfo More ...getMatchingCondition(HttpServletRequest request) {
171		RequestMethodsRequestCondition methods = methodsCondition.getMatchingCondition(request);
172		ParamsRequestCondition params = paramsCondition.getMatchingCondition(request);
173		HeadersRequestCondition headers = headersCondition.getMatchingCondition(request);
174		ConsumesRequestCondition consumes = consumesCondition.getMatchingCondition(request);
175		ProducesRequestCondition produces = producesCondition.getMatchingCondition(request);
176
177		if (methods == null || params == null || headers == null || consumes == null || produces == null) {
178			return null;
179		}
180
181		PatternsRequestCondition patterns = patternsCondition.getMatchingCondition(request);
182		if (patterns == null) {
183			return null;
184		}
185
186		RequestConditionHolder custom = customConditionHolder.getMatchingCondition(request);
187		if (custom == null) {
188			return null;
189		}
190
191		return new RequestMappingInfo(patterns, methods, params, headers, consumes, produces, custom.getCondition());
192	}
```

### doMatch 代码：

```
96 
97 	protected boolean More ...doMatch(String pattern, String path, boolean fullMatch,
98 			Map<String, String> uriTemplateVariables) {
99 
100		if (path.startsWith(this.pathSeparator) != pattern.startsWith(this.pathSeparator)) {
101			return false;
102		}
103
104		String[] pattDirs = StringUtils.tokenizeToStringArray(pattern, this.pathSeparator, this.trimTokens, true);
105		String[] pathDirs = StringUtils.tokenizeToStringArray(path, this.pathSeparator, this.trimTokens, true);
106
107		int pattIdxStart = 0;
108		int pattIdxEnd = pattDirs.length - 1;
109		int pathIdxStart = 0;
110		int pathIdxEnd = pathDirs.length - 1;
111
112		// Match all elements up to the first **
113		while (pattIdxStart <= pattIdxEnd && pathIdxStart <= pathIdxEnd) {
114			String patDir = pattDirs[pattIdxStart];
115			if ("**".equals(patDir)) {
116				break;
117			}
118			if (!matchStrings(patDir, pathDirs[pathIdxStart], uriTemplateVariables)) {
119				return false;
120			}
121			pattIdxStart++;
122			pathIdxStart++;
123		}
124
125		if (pathIdxStart > pathIdxEnd) {
126			// Path is exhausted, only match if rest of pattern is * or **'s
127			if (pattIdxStart > pattIdxEnd) {
128				return (pattern.endsWith(this.pathSeparator) ? path.endsWith(this.pathSeparator) :
129						!path.endsWith(this.pathSeparator));
130			}
131			if (!fullMatch) {
132				return true;
133			}
134			if (pattIdxStart == pattIdxEnd && pattDirs[pattIdxStart].equals("*") && path.endsWith(this.pathSeparator)) {
135				return true;
136			}
137			for (int i = pattIdxStart; i <= pattIdxEnd; i++) {
138				if (!pattDirs[i].equals("**")) {
139					return false;
140				}
141			}
142			return true;
143		}
144		else if (pattIdxStart > pattIdxEnd) {
145			// String not exhausted, but pattern is. Failure.
146			return false;
147		}
148		else if (!fullMatch && "**".equals(pattDirs[pattIdxStart])) {
149			// Path start definitely matches due to "**" part in pattern.
150			return true;
151		}
152
153		// up to last '**'
154		while (pattIdxStart <= pattIdxEnd && pathIdxStart <= pathIdxEnd) {
155			String patDir = pattDirs[pattIdxEnd];
156			if (patDir.equals("**")) {
157				break;
158			}
159			if (!matchStrings(patDir, pathDirs[pathIdxEnd], uriTemplateVariables)) {
160				return false;
161			}
162			pattIdxEnd--;
163			pathIdxEnd--;
164		}
165		if (pathIdxStart > pathIdxEnd) {
166			// String is exhausted
167			for (int i = pattIdxStart; i <= pattIdxEnd; i++) {
168				if (!pattDirs[i].equals("**")) {
169					return false;
170				}
171			}
172			return true;
173		}
174
175		while (pattIdxStart != pattIdxEnd && pathIdxStart <= pathIdxEnd) {
176			int patIdxTmp = -1;
177			for (int i = pattIdxStart + 1; i <= pattIdxEnd; i++) {
178				if (pattDirs[i].equals("**")) {
179					patIdxTmp = i;
180					break;
181				}
182			}
183			if (patIdxTmp == pattIdxStart + 1) {
184				// '**/**' situation, so skip one
185				pattIdxStart++;
186				continue;
187			}
188			// Find the pattern between padIdxStart & padIdxTmp in str between
189			// strIdxStart & strIdxEnd
190			int patLength = (patIdxTmp - pattIdxStart - 1);
191			int strLength = (pathIdxEnd - pathIdxStart + 1);
192			int foundIdx = -1;
193
194			strLoop:
195			for (int i = 0; i <= strLength - patLength; i++) {
196				for (int j = 0; j < patLength; j++) {
197					String subPat = pattDirs[pattIdxStart + j + 1];
198					String subStr = pathDirs[pathIdxStart + i + j];
199					if (!matchStrings(subPat, subStr, uriTemplateVariables)) {
200						continue strLoop;
201					}
202				}
203				foundIdx = pathIdxStart + i;
204				break;
205			}
206
207			if (foundIdx == -1) {
208				return false;
209			}
210
211			pattIdxStart = patIdxTmp;
212			pathIdxStart = foundIdx + patLength;
213		}
214
215		for (int i = pattIdxStart; i <= pattIdxEnd; i++) {
216			if (!pattDirs[i].equals("**")) {
217				return false;
218			}
219		}
220
221		return true;
222	}
```

最后补一个找到瓶颈点后 Google到类似问题的文章，并给出了具体数据和解决方法：[http://www.cnblogs.com/ucos/articles/5542012.html](http://www.cnblogs.com/ucos/articles/5542012.html)

以及这篇文章中给出的优化前后对比图：
![screenshot](/images/oss/3c61ad759ae5f44bbb2a24e4714c2ee8)
