import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'client_mixin.dart';
import 'client_base.dart';
import 'enums.dart';
import 'exception.dart';
import 'response.dart';
import 'input_file.dart';
import 'upload_progress.dart';

ClientBase createClient({
  required String endPoint,
  required bool selfSigned,
}) =>
    ClientIO(
      endPoint: endPoint,
      selfSigned: selfSigned,
    );

class ClientIO extends ClientBase with ClientMixin {
  static const int CHUNK_SIZE = 5*1024*1024;
  String _endPoint;
  Map<String, String>? _headers;
  @override
  late Map<String, String> config;
  late http.Client _httpClient;
  late HttpClient _nativeClient;

  ClientIO({
    String endPoint = 'https://HOSTNAME/v1',
    bool selfSigned = false,
  }) : _endPoint = endPoint {
    _nativeClient = HttpClient()
      ..badCertificateCallback =
          ((X509Certificate cert, String host, int port) => selfSigned);
    _httpClient = IOClient(_nativeClient);
    _endPoint = endPoint;
    _headers = {
      'content-type': 'application/json',
      'x-sdk-name': 'Dart',
      'x-sdk-platform': 'server',
      'x-sdk-language': 'dart',
      'x-sdk-version': '7.3.0',
      'X-Appwrite-Response-Format' : '1.0.0',
    };

    config = {};

    assert(_endPoint.startsWith(RegExp("http://|https://")),
        "endPoint $_endPoint must start with 'http'");
  }

  @override
  String get endPoint => _endPoint;

     /// Your project ID
    @override
    ClientIO setProject(value) {
        config['project'] = value;
        addHeader('X-Appwrite-Project', value);
        return this;
    }
     /// Your secret API key
    @override
    ClientIO setKey(value) {
        config['key'] = value;
        addHeader('X-Appwrite-Key', value);
        return this;
    }
     /// Your secret JSON Web Token
    @override
    ClientIO setJWT(value) {
        config['jWT'] = value;
        addHeader('X-Appwrite-JWT', value);
        return this;
    }
    @override
    ClientIO setLocale(value) {
        config['locale'] = value;
        addHeader('X-Appwrite-Locale', value);
        return this;
    }

  @override
  ClientIO setSelfSigned({bool status = true}) {
    _nativeClient.badCertificateCallback =
        ((X509Certificate cert, String host, int port) => status);
    return this;
  }

  @override
  ClientIO setEndpoint(String endPoint) {
    _endPoint = endPoint;
    return this;
  }

  @override
  ClientIO addHeader(String key, String value) {
    _headers![key] = value;
    return this;
  }

  @override
  Future<Response> chunkedUpload({
    required String path,
    required Map<String, dynamic> params,
    required String paramName,
    required String idParamName,
    required Map<String, String> headers,
    Function(UploadProgress)? onProgress,
  }) async {
    InputFile file = params[paramName];
    if (file.path == null && file.bytes == null) {
      throw AppwriteException("File path or bytes must be provided");
    }

    int size = 0;
    if (file.bytes != null) {
      size = file.bytes!.length;
    }

    File? iofile;

    if (file.path != null) {
      iofile = File(file.path!);
      size = await iofile.length();
    }

    late Response res;
    if (size <= CHUNK_SIZE) {
      if (file.path != null) {
        params[paramName] = await http.MultipartFile.fromPath(
            paramName, file.path!,
            filename: file.filename);
      } else {
        params[paramName] = http.MultipartFile.fromBytes(paramName, file.bytes!,
            filename: file.filename);
      }
      return call(
        HttpMethod.post,
        path: path,
        params: params,
        headers: headers,
      );
    }

    var offset = 0;
    if (idParamName.isNotEmpty && params[idParamName] != 'unique()') {
      //make a request to check if a file already exists
      try {
        res = await call(
          HttpMethod.get,
          path: path + '/' + params[idParamName],
          headers: headers,
        );
        final int chunksUploaded = res.data['chunksUploaded'] as int;
        offset = min(size, chunksUploaded * CHUNK_SIZE);
      } on AppwriteException catch (_) {}
    }

    RandomAccessFile? raf;
    // read chunk and upload each chunk
    if (iofile != null) {
      raf = await iofile.open(mode: FileMode.read);
    }

    while (offset < size) {
      var chunk;
      if (file.bytes != null) {
        final end = min(offset + CHUNK_SIZE-1, size-1);
        chunk = file.bytes!.getRange(offset, end).toList();
      } else {
        raf!.setPositionSync(offset);
        chunk = raf.readSync(CHUNK_SIZE);
      }
      params[paramName] =
          http.MultipartFile.fromBytes(paramName, chunk, filename: file.filename);
      headers['content-range'] =
          'bytes $offset-${min<int>(((offset + CHUNK_SIZE) - 1), size)}/$size';
      res = await call(HttpMethod.post,
          path: path, headers: headers, params: params);
      offset += CHUNK_SIZE;
      if (offset < size) {
        headers['x-appwrite-id'] = res.data['\$id'];
      }
      final progress = UploadProgress(
        $id: res.data['\$id'] ?? '',
        progress: min(offset - 1, size) / size * 100,
        sizeUploaded: min(offset - 1, size),
        chunksTotal: res.data['chunksTotal'] ?? 0,
        chunksUploaded: res.data['chunksUploaded'] ?? 0,
      );
      onProgress?.call(progress);
    }
    raf?.close();
    return res;
  }

  @override
  Future<Response> call(
    HttpMethod method, {
    String path = '',
    Map<String, String> headers = const {},
    Map<String, dynamic> params = const {},
    ResponseType? responseType,
  }) async {
    late http.Response res;
    http.BaseRequest request = prepareRequest(
      method,
      uri: Uri.parse(_endPoint + path),
      headers: {..._headers!, ...headers},
      params: params,
    );

    try {
      final streamedResponse = await _httpClient.send(request);
      res = await toResponse(streamedResponse);
      return prepareResponse(
        res,
        responseType: responseType,
      );
    } catch (e) {
      if (e is AppwriteException) {
        rethrow;
      }
      throw AppwriteException(e.toString());
    }
  }
}
