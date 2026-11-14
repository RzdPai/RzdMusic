export class TextUtils {
  private static readonly decEntityRegex = new RegExp('&#(\\d+);', 'g');
  private static readonly hexEntityRegex = new RegExp('&#x([0-9a-fA-F]+);', 'g');
  private static readonly urlRegex = new RegExp('https?://[^\\s\\u4e00-\\u9fff\\u3000-\\u303f\\uff00-\\uffef]+');
  private static readonly trailingPunct = '.,;:!?)\'">】」》】。，；：！？）';

  static extractUrl(text: string): string {
    const match = TextUtils.urlRegex.exec(text);
    if (match === null || match.length < 1) {
      return '';
    }
    let url = match[0];
    while (url.length > 0 && TextUtils.trailingPunct.indexOf(url.charAt(url.length - 1)) >= 0) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static decodeName(text: string): string {
    if (text.length === 0) {
      return '';
    }
    let result = text.replace(TextUtils.decEntityRegex, (match: string, code: string): string => {
      const num = Number(code);
      if (num > 0 && num < 0x110000) {
        return String.fromCharCode(num);
      }
      return match;
    });
    result = result.replace(TextUtils.hexEntityRegex, (match: string, code: string): string => {
      const num = parseInt(code, 16);
      if (num > 0 && num < 0x110000) {
        return String.fromCharCode(num);
      }
      return match;
    });
    result = result.split('&amp;').join('&');
    result = result.split('&quot;').join('"');
    result = result.split('&apos;').join('\'');
    result = result.split('&lt;').join('<');
    result = result.split('&gt;').join('>');
    result = result.split('&nbsp;').join(' ');
    return result;
  }
}
