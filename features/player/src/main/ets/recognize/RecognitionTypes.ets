// Recognition domain types — mirrors LX Music MusicRecognition types.
export enum RecognitionStatus {
  Idle = 'idle',
  RequestingPermission = 'requestingPermission',
  Capturing = 'capturing',
  Recognizing = 'recognizing',
  Matched = 'matched',
  NotMatched = 'notMatched',
  PermissionDenied = 'permissionDenied',
  NoAudio = 'noAudio',
  NetworkError = 'networkError',
  Error = 'error',
}

export class EngineReport {
  engine: string = '';
  status: string = '';

  static create(engine: string, status: string): EngineReport {
    const report = new EngineReport();
    report.engine = engine;
    report.status = status;
    return report;
  }
}

export class EngineResultGroup {
  engine: string = '';
  results: Array<RecognitionResult> = [];
  error: string = '';

  static create(engine: string, results: Array<RecognitionResult>, error: string): EngineResultGroup {
    const group = new EngineResultGroup();
    group.engine = engine;
    group.results = results;
    group.error = error;
    return group;
  }
}

export class RecognitionResult {
  id: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  coverUrl: string = '';
  provider: string = '';
  providerTrackId: string = '';
  recognizedAt: number = 0;

  static create(title: string, artist: string, album: string, coverUrl: string,
    providerTrackId: string, recognizedAt: number): RecognitionResult {
    const result = new RecognitionResult();
    result.id = `rec_${providerTrackId}:${recognizedAt}`;
    result.title = title;
    result.artist = artist;
    result.album = album;
    result.coverUrl = coverUrl;
    result.providerTrackId = providerTrackId;
    result.recognizedAt = recognizedAt;
    return result;
  }

  toRecord(): Record<string, Object> {
    return {
      'id': this.id,
      'title': this.title,
      'artist': this.artist,
      'album': this.album,
      'coverUrl': this.coverUrl,
      'provider': this.provider,
      'providerTrackId': this.providerTrackId,
      'recognizedAt': this.recognizedAt,
    };
  }

  static fromRecord(record: Record<string, Object>): RecognitionResult {
    const result = new RecognitionResult();
    result.id = record['id'] as string;
    result.title = record['title'] as string;
    result.artist = record['artist'] as string;
    result.album = record['album'] as string;
    result.coverUrl = record['coverUrl'] as string;
    result.provider = record['provider'] as string;
    result.providerTrackId = record['providerTrackId'] as string;
    result.recognizedAt = record['recognizedAt'] as number;
    return result;
  }
}
