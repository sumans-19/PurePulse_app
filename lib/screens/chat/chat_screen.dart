import 'dart:async'; // Required for the Timer
import 'package:flutter/material.dart';
import 'package:purepulse_app/models/chat_message.dart';
import 'package:purepulse_app/services/gemini_chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GeminiChatService _geminiService = GeminiChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // --- Debounce variables to prevent rapid API calls ---
  Timer? _debounce;
  final _debounceDuration = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
        text: "Hi! I'm PurePulse Assist. How can I help you today with air quality or the app?",
        isUser: false));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _debounce?.cancel(); // Important: cancel the timer when the screen is closed
    super.dispose();
  }

  void _sendMessage() {
    // 1. Check if the debounce timer is active. If so, do nothing.
    if (_debounce?.isActive ?? false) {
      print("Debounce active, ignoring send request.");
      return;
    }
    // 2. Start a new timer to create a cooldown period.
    _debounce = Timer(_debounceDuration, () {});

    final userQuery = _textController.text;
    if (userQuery.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: userQuery, isUser: true));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    // Call the actual API logic
    _fetchAiResponse(userQuery);
  }

  Future<void> _fetchAiResponse(String query) async {
    final aiResponse = await _geminiService.getChatResponse(query);

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: aiResponse, isUser: false));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }
  
  void _scrollToBottom() {
    // A small delay ensures the list has time to build before scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PurePulse Assist')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return const _TypingIndicator();
                }
                final message = _messages[index];
                return _ChatMessageBubble(message: message);
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Ask a question...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                onSubmitted: _isLoading ? null : (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _isLoading ? null : _sendMessage,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final align = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = message.isUser ? Theme.of(context).primaryColor : Colors.grey.shade200;
    final textColor = message.isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message.text, style: TextStyle(color: textColor, fontSize: 15)),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _ChatMessageBubble(
        message: ChatMessage(text: '...', isUser: false),
      ),
    );
  }
}