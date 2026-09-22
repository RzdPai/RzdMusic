export class RecognitionNetworkError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'RecognitionNetworkError';
  }
}
