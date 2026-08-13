import 'dart:async';
import 'dart:io';

import 'simple_api_client.dart';

String humanReadableError(
  Object error, {
  String action = 'memproses permintaan',
}) {
  if (error is ApiException) {
    return _apiErrorMessage(error, action: action);
  }

  if (error is SocketException) {
    return _socketErrorMessage(error);
  }

  if (error is HandshakeException) {
    return 'Koneksi aman ke server belum bisa diverifikasi. Pastikan tanggal dan jam HP benar, lalu coba lagi.';
  }

  if (error is HttpException) {
    return 'Koneksi ke server terputus saat data sedang diproses. Coba ulangi dengan jaringan yang lebih stabil.';
  }

  if (error is TimeoutException) {
    return 'Koneksi terlalu lama merespons. Coba ulangi beberapa saat lagi.';
  }

  if (error is FormatException) {
    return 'Server mengirim respons yang belum bisa dibaca aplikasi. Coba ulangi, atau hubungi admin jika masih terjadi.';
  }

  if (error is FileSystemException) {
    return 'File di HP belum bisa dibuka. Pastikan file/foto masih tersedia, lalu coba lagi.';
  }

  if (error is StateError) {
    return _stateErrorMessage(error);
  }

  return _plainErrorMessage(error.toString(), action: action);
}

String _apiErrorMessage(
  ApiException error, {
  required String action,
}) {
  final message = _cleanRawMessage(error.message);
  final lowerMessage = message.toLowerCase();

  if (error.statusCode >= 500) {
    return 'Server sedang bermasalah saat $action. Coba lagi beberapa saat lagi.';
  }

  if (error.statusCode == 401 || error.statusCode == 403) {
    return 'Sesi login tidak valid atau akun tidak punya akses. Silakan login ulang.';
  }

  if (error.statusCode == 404) {
    return 'Data atau layanan yang diminta belum ditemukan. Coba muat ulang aplikasi.';
  }

  if (error.statusCode == 413) {
    return 'Ukuran file terlalu besar. Coba pakai foto yang lebih kecil.';
  }

  if (error.statusCode == 422) {
    if (lowerMessage.contains('compensation mode')) {
      return 'Pilihan kompensasi WFA belum valid. Pilih ulang jenis WFA, lalu ajukan kembali.';
    }

    if (lowerMessage.contains('samples.') ||
        lowerMessage.contains('file_name') ||
        lowerMessage.contains('mime_type')) {
      return 'Data foto wajah belum lengkap terbaca. Ulangi pendaftaran wajah dari awal dengan kamera yang stabil.';
    }

    if (_looksTechnical(message)) {
      return 'Data belum lengkap atau belum sesuai. Periksa kembali form yang wajib diisi.';
    }

    return message.isEmpty
        ? 'Data belum lengkap atau belum sesuai. Periksa kembali form yang wajib diisi.'
        : message;
  }

  if (error.statusCode == 429) {
    return 'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.';
  }

  if (_looksTechnical(message) || message.isEmpty) {
    return 'Permintaan belum berhasil diproses. Coba ulangi beberapa saat lagi.';
  }

  return message;
}

String _socketErrorMessage(SocketException error) {
  final message = error.message.toLowerCase();
  if (message.contains('failed host lookup') ||
      message.contains('no address associated with hostname')) {
    return 'Aplikasi belum bisa menemukan server. Periksa koneksi internet atau ganti jaringan, lalu coba lagi.';
  }

  if (message.contains('connection refused')) {
    return 'Server belum bisa menerima koneksi. Coba lagi beberapa saat lagi.';
  }

  if (message.contains('connection timed out') ||
      message.contains('network is unreachable')) {
    return 'Jaringan sedang tidak stabil. Coba ulangi dengan koneksi internet yang lebih baik.';
  }

  return 'Koneksi internet bermasalah. Coba ganti jaringan atau ulangi beberapa saat lagi.';
}

String _stateErrorMessage(StateError error) {
  final message = _cleanRawMessage(error.message.toString());
  final lowerMessage = message.toLowerCase();

  if (lowerMessage.contains('upload foto gagal dibaca') ||
      lowerMessage.contains('respons')) {
    return 'Foto sudah dikirim, tapi respons server belum bisa dibaca. Coba upload ulang dengan koneksi stabil.';
  }

  if (_looksTechnical(message) || message.isEmpty) {
    return 'Data aplikasi belum siap. Coba muat ulang halaman, lalu ulangi prosesnya.';
  }

  return message;
}

String _plainErrorMessage(
  String rawMessage, {
  required String action,
}) {
  final message = _cleanRawMessage(rawMessage);
  final lowerMessage = message.toLowerCase();

  if (lowerMessage.contains('socketexception') ||
      lowerMessage.contains('failed host lookup')) {
    return 'Aplikasi belum bisa menemukan server. Periksa koneksi internet atau ganti jaringan, lalu coba lagi.';
  }

  if (lowerMessage.contains('handshakeexception') ||
      lowerMessage.contains('certificate_verify_failed')) {
    return 'Koneksi aman ke server belum bisa diverifikasi. Pastikan tanggal dan jam HP benar, lalu coba lagi.';
  }

  if (lowerMessage.contains('formatexception') ||
      lowerMessage.contains('unexpected character') ||
      lowerMessage.contains('<br')) {
    return 'Server mengirim respons yang belum bisa dibaca aplikasi. Coba ulangi, atau hubungi admin jika masih terjadi.';
  }

  if (lowerMessage.contains('httpexception') ||
      lowerMessage.contains('connection closed')) {
    return 'Koneksi ke server terputus saat data sedang diproses. Coba ulangi dengan jaringan yang lebih stabil.';
  }

  if (lowerMessage.contains('timeoutexception')) {
    return 'Koneksi terlalu lama merespons. Coba ulangi beberapa saat lagi.';
  }

  if (lowerMessage.contains('filesystemexception') ||
      lowerMessage.contains('cannot open file')) {
    return 'File di HP belum bisa dibuka. Pastikan file/foto masih tersedia, lalu coba lagi.';
  }

  if (lowerMessage.contains('bad state')) {
    return 'Data aplikasi belum siap. Coba muat ulang halaman, lalu ulangi prosesnya.';
  }

  if (_looksTechnical(message) || message.isEmpty) {
    return 'Proses $action belum berhasil. Coba ulangi beberapa saat lagi.';
  }

  return message;
}

String _cleanRawMessage(String message) {
  var cleaned = message.trim();
  final prefixes = [
    RegExp(r'^ApiException\(\d+\):\s*'),
    RegExp(r'^Exception:\s*'),
    RegExp(r'^Bad state:\s*'),
  ];

  for (final prefix in prefixes) {
    cleaned = cleaned.replaceFirst(prefix, '').trim();
  }

  return cleaned;
}

bool _looksTechnical(String message) {
  final lowerMessage = message.toLowerCase();
  return lowerMessage.contains('exception') ||
      lowerMessage.contains('http ') ||
      lowerMessage.contains('https://') ||
      lowerMessage.contains(' field is required') ||
      lowerMessage.contains('selected ') ||
      lowerMessage.contains('invalid') ||
      lowerMessage.contains(' at character ') ||
      lowerMessage.contains('<br') ||
      lowerMessage.contains('errno') ||
      lowerMessage.contains('os error') ||
      lowerMessage.contains('runtime') ||
      lowerMessage.contains('stacktrace');
}
