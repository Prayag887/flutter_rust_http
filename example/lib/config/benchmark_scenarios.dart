import 'package:flutter/material.dart';
import '../models/benchmark_models.dart';

class BenchmarkScenarios {
  static const List<BenchmarkScenario> scenarios = [
    BenchmarkScenario(
      name: 'TikTok Feed',
      description: 'High-throughput social media feed simulation',
      icon: Icons.video_library,
      method: 'GET',
      endpoint: 'https://jsonplaceholder.typicode.com/posts',
      concurrentRequests: 10,
      totalRequests: 100,
      enableComplexParsing: true,
    ),

    BenchmarkScenario(
      name: 'User Profiles',
      description: 'User data fetching with nested JSON',
      icon: Icons.people,
      method: 'GET',
      endpoint: 'https://api.github.com/users',
      concurrentRequests: 2,  // Reduced from 30
      totalRequests: 20,      // Reduced from 300
      enableComplexParsing: true,
      timeout: Duration(seconds: 10),
    ),

    BenchmarkScenario(
      name: 'Live Chat',
      description: 'Real-time messaging simulation',
      icon: Icons.chat,
      method: 'POST',
      endpoint: 'https://jsonplaceholder.typicode.com/posts',
      payload: {
        'message': 'Hello world!',
        'userId': 1,
        'timestamp': '{{timestamp}}',
      },
      concurrentRequests: 5,  // Reduced from 100
      totalRequests: 50,      // Reduced from 1000
    ),

    BenchmarkScenario(
      name: 'Comments Stream',
      description: 'Continuous comments loading',
      icon: Icons.comment,
      method: 'GET',
      endpoint: 'https://jsonplaceholder.typicode.com/comments',
      concurrentRequests: 5,  // Reduced from 75
      totalRequests: 50,      // Reduced from 750
      enableComplexParsing: true,
    ),

    BenchmarkScenario(
      name: 'Rate Limit Test',
      description: 'Controlled rate limiting test',
      icon: Icons.speed,
      method: 'GET',
      endpoint: 'https://api.github.com/repos/flutter/flutter',
      concurrentRequests: 1,  // Sequential requests only
      totalRequests: 10,      // Very conservative
      timeout: Duration(seconds: 10),
    ),

    BenchmarkScenario(
      name: 'Cache Buster',
      description: 'Fresh data fetching without cache',
      icon: Icons.refresh,
      method: 'GET',
      endpoint: 'https://httpbin.org/uuid',
      concurrentRequests: 10,
      totalRequests: 50,
      enableCacheBusting: true,
    ),

    BenchmarkScenario(
      name: 'Image Metadata',
      description: 'JSON metadata service',
      icon: Icons.image,
      method: 'GET',
      endpoint: 'https://httpbin.org/json', // Returns actual JSON
      concurrentRequests: 5,
      totalRequests: 25,
      headers: {'Accept': 'application/json'},
    ),

    BenchmarkScenario(
      name: 'Analytics Push',
      description: 'Analytics data submission',
      icon: Icons.analytics,
      method: 'POST',
      endpoint: 'https://httpbin.org/post',
      payload: {
        'event': 'user_action',
        'data': {
          'action': 'scroll',
          'timestamp': '{{timestamp}}',
          'user_id': '{{user_id}}',
        },
      },
      concurrentRequests: 5,  // Reduced from 40
      totalRequests: 25,      // Reduced from 400
    ),

    BenchmarkScenario(
      name: 'File Upload',
      description: 'Large payload upload simulation',
      icon: Icons.upload,
      method: 'PUT',
      endpoint: 'https://httpbin.org/put',
      payload: {
        'file_data': '{{large_payload}}',
        'metadata': {
          'size': 1024000,
          'type': 'application/json',
        },
      },
      concurrentRequests: 2,  // Reduced from 10
      totalRequests: 10,      // Reduced from 100
      timeout: Duration(seconds: 30),
    ),

    BenchmarkScenario(
      name: 'Search Query',
      description: 'Search API with complex responses',
      icon: Icons.search,
      method: 'GET',
      endpoint: 'https://api.github.com/search/repositories?q=flutter&sort=stars', // Added required 'q' param
      concurrentRequests: 1,  // Sequential only for search API
      totalRequests: 5,       // Very conservative
      enableComplexParsing: true,
      headers: {'Accept': 'application/vnd.github.v3+json'},
      timeout: Duration(seconds: 10),
    ),

    BenchmarkScenario(
      name: 'Basic Test',
      description: 'Simple connectivity test',
      icon: Icons.check_circle,
      method: 'GET',
      endpoint: 'https://httpbin.org/get',
      concurrentRequests: 1,
      totalRequests: 5,
      timeout: Duration(seconds: 5),
    ),
  ];

  static BenchmarkScenario getScenarioByName(String name) {
    return scenarios.firstWhere(
          (scenario) => scenario.name == name,
      orElse: () => scenarios.first,
    );
  }

  static List<BenchmarkScenario> getLightweightScenarios() {
    return scenarios.where((s) => s.totalRequests <= 50).toList();
  }

  static List<BenchmarkScenario> getHeavyScenarios() {
    return scenarios.where((s) => s.totalRequests > 50).toList();
  }

  static List<BenchmarkScenario> getReadOnlyScenarios() {
    return scenarios.where((s) => s.method == 'GET').toList();
  }

  static List<BenchmarkScenario> getWriteScenarios() {
    return scenarios.where((s) => ['POST', 'PUT', 'PATCH'].contains(s.method)).toList();
  }
}