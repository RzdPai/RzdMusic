/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * 轻量 XML 解析器（用于 TTML 歌词解析，替代浏览器 DOMParser）。
 */

/** XML 属性 */
export interface AmllXmlAttr {
  /** 属性全名（可能含前缀，如 itunes:key） */
  name: string;
  /** 属性值 */
  value: string;
}

/** XML 元素 */
export interface AmllXmlElement {
  /** 元素全名（可能含前缀，如 ttm:agent） */
  tagName: string;
  /** 本地名（去掉前缀） */
  localName: string;
  /** 前缀（无前缀为空串） */
  prefix: string;
  attributes: AmllXmlAttr[];
  children: AmllXmlNode[];
  parent: AmllXmlElement | undefined;
}

/** XML 文本节点 */
export interface AmllXmlText {
  text: string;
}

export type AmllXmlNode = AmllXmlElement | AmllXmlText;

/** 解析后的 XML 文档 */
export interface AmllXmlDocument {
  root: AmllXmlElement;
}

/** 标签名解析结果 */
interface AmllTagName {
  name: string;
  local: string;
  prefix: string;
}

const NS_PREFIX: string = 'xmlns';

function parseTagName(raw: string): AmllTagName {
  const idx = raw.indexOf(':');
  if (idx === -1) {
    const result: AmllTagName = { name: raw, local: raw, prefix: '' };
    return result;
  }
  const result: AmllTagName = {
    name: raw,
    local: raw.substring(idx + 1),
    prefix: raw.substring(0, idx)
  };
  return result;
}

function parseAttributes(raw: string): AmllXmlAttr[] {
  const attrs: AmllXmlAttr[] = [];
  const attrRe: RegExp = new RegExp('([^\\s=]+)\\s*=\\s*("([^"]*)"|\'([^\']*)\')', 'g');
  attrRe.lastIndex = 0;
  let m: RegExpExecArray | null = attrRe.exec(raw);
  while (m !== null) {
    const name: string = m[1];
    const value: string = m[3] !== undefined ? m[3] : m[4];
    attrs.push({ name: name, value: value });
    m = attrRe.exec(raw);
  }
  return attrs;
}

/**
 * 解析 XML 字符串为文档树。
 * 支持：XML 声明、注释、CDATA、DOCTYPE（简单跳过）、自闭合标签、带引号属性。
 */
export function amllParseXml(xmlStr: string): AmllXmlDocument {
  let pos = 0;
  const len = xmlStr.length;
  const root: AmllXmlElement = {
    tagName: '__root__',
    localName: '__root__',
    prefix: '',
    attributes: [],
    children: [],
    parent: undefined
  };
  let stack: AmllXmlElement[] = [root];

  const current = (): AmllXmlElement => stack[stack.length - 1];

  const addText = (text: string): void => {
    if (text.length === 0) {
      return;
    }
    const node: AmllXmlText = { text: text };
    const parent = current();
    parent.children.push(node);
  };

  while (pos < len) {
    const lt = xmlStr.indexOf('<', pos);
    if (lt === -1) {
      addText(xmlStr.substring(pos));
      break;
    }
    if (lt > pos) {
      addText(xmlStr.substring(pos, lt));
    }
    // 处理 <...>
    const gt = xmlStr.indexOf('>', lt);
    if (gt === -1) {
      addText(xmlStr.substring(lt));
      break;
    }
    let inner = xmlStr.substring(lt + 1, gt);
    pos = gt + 1;

    if (inner.startsWith('?')) {
      // 处理指令（XML 声明等）
      const close = xmlStr.indexOf('?>', lt);
      if (close !== -1) {
        pos = close + 2;
      }
      continue;
    }
    if (inner.startsWith('!--')) {
      const close = xmlStr.indexOf('-->', lt);
      if (close !== -1) {
        pos = close + 3;
      } else {
        break;
      }
      continue;
    }
    if (inner.startsWith('![CDATA[')) {
      const close = xmlStr.indexOf(']]>', lt);
      if (close !== -1) {
        addText(xmlStr.substring(lt + 9, close));
        pos = close + 3;
      } else {
        break;
      }
      continue;
    }
    if (inner.startsWith('!')) {
      // DOCTYPE 等：跳过到闭合的 >（简单处理）
      continue;
    }
    if (inner.startsWith('/')) {
      // 结束标签
      const name = inner.substring(1).trim();
      if (stack.length > 1) {
        stack.pop();
      }
      continue;
    }
    // 开始标签
    let selfClosing = false;
    if (inner.endsWith('/')) {
      selfClosing = true;
      inner = inner.substring(0, inner.length - 1);
    }
    inner = inner.trim();
    // 分离标签名与属性
    let nameEnd = inner.search(/[\s]/);
    if (nameEnd === -1) {
      nameEnd = inner.length;
    }
    const nameRaw = inner.substring(0, nameEnd);
    const attrRaw = inner.substring(nameEnd).trim();
    const parsed = parseTagName(nameRaw);
    const element: AmllXmlElement = {
      tagName: parsed.name,
      localName: parsed.local,
      prefix: parsed.prefix,
      attributes: parseAttributes(attrRaw),
      children: [],
      parent: current()
    };
    current().children.push(element);
    if (!selfClosing) {
      stack.push(element);
    }
  }

  if (root.children.length === 0 || root.children[0] === undefined) {
    throw new Error('XML 解析失败: 无根元素');
  }
  const firstEl = root.children[0];
  if ((firstEl as AmllXmlText).text !== undefined) {
    throw new Error('XML 解析失败: 无根元素');
  }
  return { root: firstEl as AmllXmlElement };
}

/** 收集所有匹配 localName 的元素（含子孙） */
export function amllXmlGetElementsByTagName(
  element: AmllXmlElement,
  localName: string
): AmllXmlElement[] {
  const result: AmllXmlElement[] = [];
  const walk = (el: AmllXmlElement): void => {
    for (let i = 0; i < el.children.length; i++) {
      const child = el.children[i];
      if ((child as AmllXmlText).text !== undefined) {
        continue;
      }
      const childEl = child as AmllXmlElement;
      if (childEl.localName === localName) {
        result.push(childEl);
      }
      walk(childEl);
    }
  };
  walk(element);
  return result;
}

/** 收集所有匹配 (ns 前缀, localName) 的元素（含子孙） */
export function amllXmlGetElementsByTagNameNS(
  element: AmllXmlElement,
  prefix: string,
  localName: string
): AmllXmlElement[] {
  const result: AmllXmlElement[] = [];
  const walk = (el: AmllXmlElement): void => {
    for (let i = 0; i < el.children.length; i++) {
      const child = el.children[i];
      if ((child as AmllXmlText).text !== undefined) {
        continue;
      }
      const childEl = child as AmllXmlElement;
      if (childEl.localName === localName && (prefix === '*' || childEl.prefix === prefix)) {
        result.push(childEl);
      }
      walk(childEl);
    }
  };
  walk(element);
  return result;
}

/** 获取元素的文本内容（全部子文本拼接） */
export function amllXmlTextContent(element: AmllXmlElement): string {
  let result = '';
  const walk = (el: AmllXmlElement): void => {
    for (let i = 0; i < el.children.length; i++) {
      const child = el.children[i];
      if ((child as AmllXmlText).text !== undefined) {
        result += (child as AmllXmlText).text;
      } else {
        walk(child as AmllXmlElement);
      }
    }
  };
  walk(element);
  return result;
}

/** 获取属性的值（本地名匹配，忽略命名空间） */
export function amllXmlGetAttr(
  element: AmllXmlElement,
  localName: string
): string | undefined {
  for (let i = 0; i < element.attributes.length; i++) {
    const attr = element.attributes[i];
    const idx = attr.name.indexOf(':');
    const local = idx === -1 ? attr.name : attr.name.substring(idx + 1);
    if (local === localName) {
      return attr.value;
    }
  }
  return undefined;
}

/**
 * 获取带命名空间前缀的属性值；找不到时回退到本地名匹配
 * 返回 undefined 表示不存在
 */
export function amllXmlGetAttrNS(
  element: AmllXmlElement,
  prefix: string,
  localName: string
): string | undefined {
  const fullName = `${prefix}:${localName}`;
  for (let i = 0; i < element.attributes.length; i++) {
    if (element.attributes[i].name === fullName) {
      return element.attributes[i].value;
    }
  }
  return amllXmlGetAttr(element, localName);
}

/** 直接子节点列表（元素+文本混合） */
export function amllXmlChildNodes(element: AmllXmlElement): AmllXmlNode[] {
  return element.children;
}
