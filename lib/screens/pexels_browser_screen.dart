import 'package:flutter/material.dart';
import '../services/pexels_service.dart';

/// Browse and download kid-friendly stock videos from Pexels.
/// Returns the local file path of the downloaded video, or null if cancelled.
class PexelsBrowserScreen extends StatefulWidget {
  const PexelsBrowserScreen({super.key});

  @override
  State<PexelsBrowserScreen> createState() => _PexelsBrowserScreenState();
}

class _PexelsBrowserScreenState extends State<PexelsBrowserScreen> {
  final _service = PexelsService();
  final _searchController = TextEditingController();
  List<PexelsVideo> _videos = [];
  List<String> _topics = [];
  bool _loading = false;
  String? _error;
  String _currentQuery = '';
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final topics = await _service.topics();
      final videos = await _service.popular();
      setState(() {
        _topics = topics;
        _videos = videos;
        _currentQuery = 'Popular';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _currentQuery = query;
    });
    try {
      final videos = await _service.search(query);
      setState(() => _videos = videos);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _downloadAndReturn(PexelsVideo video) async {
    setState(() => _downloading = true);
    double progress = 0;
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Downloading...', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress > 0 ? progress : null),
                const SizedBox(height: 12),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );

      final path = await _service.downloadVideo(
        video.downloadUrl,
        onProgress: (p) {
          progress = p;
          if (mounted) setState(() {});
        },
      );

      if (mounted) {
        Navigator.pop(context); // dismiss progress dialog
        Navigator.pop(context, path); // return path to caller
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss progress dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[850],
        title: const Text('Browse Videos 🎬'),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search for videos...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _searchController.clear();
                          _loadInitial();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _search,
            ),
          ),
          // Topic chips
          if (_topics.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _topics.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: Colors.grey[800],
                    label: Text(
                      _topics[i],
                      style: const TextStyle(color: Colors.white),
                    ),
                    onPressed: () {
                      _searchController.text = _topics[i];
                      _search(_topics[i]);
                    },
                  ),
                ),
              ),
            ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _currentQuery,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_videos.isNotEmpty)
                  Text(
                    '${_videos.length} videos',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
              ],
            ),
          ),
          // Results grid
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadInitial,
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _videos.isEmpty
                        ? const Center(
                            child: Text(
                              'No videos found',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 9 / 16,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _videos.length,
                            itemBuilder: (ctx, i) {
                              final v = _videos[i];
                              return GestureDetector(
                                onTap: _downloading ? null : () => _downloadAndReturn(v),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        v.thumbnail,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.broken_image, color: Colors.white),
                                        ),
                                      ),
                                      // Duration overlay
                                      Positioned(
                                        bottom: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${v.duration}s',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Author credit
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black87,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            v.user,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
