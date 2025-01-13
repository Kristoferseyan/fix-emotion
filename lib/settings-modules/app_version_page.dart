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
  bool _tokenError = false;

  final String personalAccessToken = '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';

  @override
  void initState() {
    super.initState();
    _fetchReleases();
  }

  Future<void> _fetchReleases() async {
    final url = 'https://api.github.com/repos/Kristoferseyan/eMotion/releases';

    final headers = {
      'Authorization': 'token $personalAccessToken',
    };

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          _releases = json.decode(response.body);
          _isLoading = false;
          _tokenError = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() {
          _isLoading = false;
          _tokenError = true; 
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        throw Exception('Failed to load releases');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _tokenError = true; 
      });
      print('Error fetching releases: $e');
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
          : _tokenError
              ? Center(
                  child: Text(
                    'Access token is invalid or expired. Please update the token.',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _releases.length,
                  itemBuilder: (context, index) {
                    final release = _releases[index];
                    return Card(
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      color: isDarkMode
                          ? const Color(0xFF1D4D4F) 
                          : const Color(0xFFFFFFFF), 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent, 
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
                              ? const Color(0xFF284A4F) 
                              : const Color(0xFFFAFAFA), 
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color(0xFF284A4F) 
                                    : const Color(0xFFFAFAFA), 
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
