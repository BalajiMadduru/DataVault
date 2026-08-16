import 'package:flutter/material.dart';

class ExpandableTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<Widget> children;

  const ExpandableTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: const Color(0xFF0F172A)),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          trailing: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: const Color(0xFF64748B),
          ),
          onTap: onTap,
        ),
        if (isExpanded)
          Container(
            padding: const EdgeInsets.only(left: 48),
            child: Column(
              children: children,
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class SubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const SubTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF334155),
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}