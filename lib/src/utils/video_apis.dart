import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/vimeo_models.dart';

String podErrorString(String val) {
  return '*\n------error------\n\n$val\n\n------end------\n*';
}

class VideoApis {
  static Future<Response> _makeRequestHash(
    String videoId,
    String token,
    String? hash,
  ) {
    return http.get(
      Uri.parse('https://api.vimeo.com/videos/$videoId?fields=play'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.vimeo.*+json;version=3.4',
        // 'Content-Type': 'application/json',
      },
    );
  }

  static Future<List<VideoQalityUrls>?> getVimeoVideoQualityUrls(
    String videoId,
    String token,
    String? hash,
  ) async {
    try {
      print(videoId);
      print('token: $token');
      final response = await _makeRequestHash(videoId, token, hash);
      final jsonData = jsonDecode(response.body)['play'];
      // final dashData = jsonData['dash'];
      // final hlsData = jsonData['hls'];
      print(response.statusCode);
      print(response.body);
      print('progressive');
      print(jsonData);
      final List<dynamic> rawStreamUrls =
          (jsonData['progressive'] as List<dynamic>?) ?? <dynamic>[];
      final List<VideoQalityUrls> vimeoQualityUrls = [];

      for (final item in rawStreamUrls) {
        vimeoQualityUrls.add(
          VideoQalityUrls(
            quality: (item['height'] as int?) ?? 0,
            url: item['link'] as String,
          ),
        );
      }
      if (vimeoQualityUrls.isEmpty) {
        vimeoQualityUrls.add(
          VideoQalityUrls(
            quality: 720,
            url: '',
          ),
        );
      }
      return vimeoQualityUrls;
    } catch (error) {
      if (error.toString().contains('XMLHttpRequest')) {
        log(
          podErrorString(
            '(INFO) To play vimeo video in WEB, Please enable CORS in your browser',
          ),
        );
      }
      debugPrint('===== VIMEO API ERROR: $error ==========');
      rethrow;
    }
  }

  static Future<List<VideoQalityUrls>?> getVimeoPrivateVideoQualityUrls(
    String videoId,
    Map<String, String> httpHeader,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.vimeo.com/videos/$videoId'),
        headers: httpHeader,
      );
      final jsonData =
          (jsonDecode(response.body)['files'] as List<dynamic>?) ?? [];

      final List<VideoQalityUrls> list = [];
      for (int i = 0; i < jsonData.length; i++) {
        final String quality =
            (jsonData[i]['rendition'] as String?)?.split('p').first ?? '0';
        final int? number = int.tryParse(quality);
        if (number != null && number != 0) {
          list.add(
            VideoQalityUrls(
              quality: number,
              url: jsonData[i]['link'] as String,
            ),
          );
        }
      }
      return list;
    } catch (error) {
      if (error.toString().contains('XMLHttpRequest')) {
        log(
          podErrorString(
            '(INFO) To play vimeo video in WEB, Please enable CORS in your browser',
          ),
        );
      }
      debugPrint('===== VIMEO API ERROR: $error ==========');
      rethrow;
    }
  }

  static Future<List<VideoQalityUrls>?> getYoutubeVideoQualityUrls(
    String youtubeIdOrUrl,
    bool live,
  ) async {
    try {
      final yt = YoutubeExplode();
      final urls = <VideoQalityUrls>[];
      if (live) {
        final url = await yt.videos.streamsClient.getHttpLiveStreamUrl(
          VideoId(youtubeIdOrUrl),
        );
        urls.add(
          VideoQalityUrls(
            quality: 360,
            url: url,
          ),
        );
      } else {
        final manifest =
            await yt.videos.streamsClient.getManifest(youtubeIdOrUrl);
        urls.addAll(
          manifest.muxed.map(
            (element) => VideoQalityUrls(
              quality: int.parse(element.qualityLabel.split('p')[0]),
              url: element.url.toString(),
            ),
          ),
        );
      }
      // Close the YoutubeExplode's http client.
      yt.close();
      return urls;
    } catch (error) {
      if (error.toString().contains('XMLHttpRequest')) {
        log(
          podErrorString(
            '(INFO) To play youtube video in WEB, Please enable CORS in your browser',
          ),
        );
      }
      debugPrint('===== YOUTUBE API ERROR: $error ==========');
      rethrow;
    }
  }
}
