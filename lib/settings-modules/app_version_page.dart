import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AppVersionPage extends StatefulWidget {
  @override
  _AppVersionPageState createState() => _AppVersionPageState();
}

class _AppVersionPageState extends State<AppVersionPage> {
  List<dynamic> _releases = [];
  bool _isLoading = true;

  // Replace with your personal access token
  final String personalAccessToken = 'YOUR_PERSONAL_ACCESS_TOKEN';

  @override
  void initState() {
    super.initState();
    _fetchReleases();
  }

  Future<void> _fetchReleases() async {
    final url = 'https://api.github.com/repos/Kristoferseyan/fix-emotion/releases';

    final headers = {
      'Authorization': 'token $personalAccessToken',
    };

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      setState(() {
        _releases = json.decode(response.body);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      throw Exception('Failed to load releases');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF122E31) : const Color(0xFFF3FCFF),
      appBar: AppBar(
        title: const Text('App Version and Releases'),
        backgroundColor: isDarkMode ? const Color(0xFF0D2C2D) : const Color(0xFFB6DDF2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _releases.length,
              itemBuilder: (context, index) {
                final release = _releases[index];
                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: isDarkMode
                      ? const Color(0xFF1D4D4F) // Dark mode card color
                      : const Color(0xFFFFFFFF), // Light mode card color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent, // Hide the divider line
                    ),
                    child: ExpansionTile(
                      collapsedIconColor: isDarkMode ? Colors.white : const Color(0xFF317B85),
                      iconColor: isDarkMode ? Colors.white : const Color(0xFF317B85),
                      title: Text(
                        release['name'] ?? 'Unnamed Release',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : const Color(0xFF317B85),
                        ),
                      ),
                      backgroundColor: isDarkMode
                          ? const Color(0xFF284A4F) // Dark mode expanded background
                          : const Color(0xFFFAFAFA), // Light mode expanded background
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF284A4F) // Expanded container dark color
                                : const Color(0xFFFAFAFA), // Expanded container light color
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Published on: ${release['published_at'] != null ? DateTime.parse(release['published_at']).toLocal().toString() : 'Unknown'}',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                release['body'] ?? 'No release notes',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white54 : const Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
