part of '../main.dart';

// ─────────────────────────────────────────────────────────────
// DETALLES: evento y noticia (destino al tocar en el Panel y en las listas)
// ─────────────────────────────────────────────────────────────

void _openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

String _categoryLabel(String c) =>
    const {'item': 'Objeto', 'honor': 'Título', 'character': 'Trekker', 'disc': 'Disco'}[c.toLowerCase()] ?? c;

class EventDetailPage extends StatelessWidget {
  const EventDetailPage({super.key, required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final tex = _asMap(e['textures']);
    final art = _imageChain(tex, ['banner', 'tabBackground', 'background']);
    final start = _parseDate(e['startTime']);
    final end = _parseDate(e['endTime']);
    final claim = _parseDate(e['claimEndTime']);
    final now = DateTime.now();
    final status = start != null && now.isBefore(start)
        ? 'EMPIEZA EN ${_remaining(start)}'
        : end != null && now.isBefore(end)
        ? 'TERMINA EN ${_remaining(end)}'
        : claim != null && now.isBefore(claim)
        ? 'CANJE HASTA ${_remaining(claim)}'
        : 'FINALIZADO';
    final rewards = _asList(e['rewards']).map(_asMap).toList();
    final milestones = _asList(e['milestones']).map(_asMap).toList();
    final shops = _asList(e['shops']).map(_asMap).toList();
    final desc = _cleanGameText(_string(e['description']));

    return Scaffold(
      appBar: _subAppBar(_string(e['title'], 'Evento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          if (art.isNotEmpty)
            Container(
              decoration: BoxDecoration(border: Border.all(color: kBorderHighlight, width: 2)),
              child: AspectRatio(
                aspectRatio: 2.4,
                child: _NetImage(art.first, alt: art.skip(1).toList(), fallbackIcon: Icons.event_outlined),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _Tag(status, filled: !status.startsWith('FIN')),
            _Tag('${_shortDate(start)} – ${_shortDate(end)}'),
          ]),
          const SizedBox(height: 10),
          Text(_string(e['title']).toUpperCase(), style: kDisplay(28)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(desc, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xffd9d6d0))),
          ],
          if (rewards.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Panel(
              title: 'Recompensas',
              badge: '${rewards.length} objetos',
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 10, children: [
                for (final r in rewards)
                  SizedBox(
                    width: 74,
                    child: Column(children: [
                      _itemThumb(r['id'], size: 56),
                      const SizedBox(height: 4),
                      Text(_string(r['name']),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      if (r['quantity'] != null)
                        Text('×${_formatNumber(_string(r['quantity']))}', style: const TextStyle(fontSize: 10, color: kTextMuted))
                      else if (_string(r['category']).isNotEmpty)
                        Text(_categoryLabel(_string(r['category'])), style: const TextStyle(fontSize: 9, color: kTextMuted)),
                    ]),
                  ),
              ]),
            ),
          ],
          if (milestones.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Panel(
              title: 'Objetivos',
              badge: '${milestones.length}',
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                for (final m in milestones)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorderColor))),
                    child: Row(children: [
                      Expanded(child: Text(_cleanGameText(_string(m['description'])), style: const TextStyle(fontSize: 12, height: 1.35))),
                      for (final r in _asList(m['rewards']).map(_asMap).take(3))
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Column(children: [
                            _itemThumb(r['id'], size: 30),
                            if (r['quantity'] != null)
                              Text('×${_formatNumber(_string(r['quantity']))}', style: const TextStyle(fontSize: 9)),
                          ]),
                        ),
                    ]),
                  ),
              ]),
            ),
          ],
          for (final s in shops) ...[const SizedBox(height: 16), _shopList(s)],
        ],
      ),
    );
  }
}

class NewsDetailPage extends StatelessWidget {
  const NewsDetailPage({super.key, required this.news});
  final Map<String, dynamic> news;

  @override
  Widget build(BuildContext context) {
    final n = news;
    final published = _parseDate(int.tryParse(_string(n['publishTime'])));
    final link = _string(n['link']);
    return Scaffold(
      appBar: _subAppBar(_newsTypeLabel(_string(n['type']))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          if (_string(n['thumbnail']).isNotEmpty)
            Container(
              decoration: BoxDecoration(border: Border.all(color: kBorderHighlight, width: 2)),
              child: AspectRatio(aspectRatio: 16 / 9, child: _NetImage(_string(n['thumbnail']))),
            ),
          const SizedBox(height: 12),
          Row(children: [
            _Tag(_newsTypeLabel(_string(n['type'])), filled: true),
            const SizedBox(width: 8),
            Text(_shortDate(published), style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Text(_string(n['title']).toUpperCase(), style: kDisplay(26)),
          const SizedBox(height: 12),
          Text(_cleanHtml(_string(n['description'])), style: const TextStyle(fontSize: 13.5, height: 1.55)),
          if (link.isNotEmpty) ...[
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: kTextPrimary, width: 2),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              child: const Text('ABRIR EN LA WEB OFICIAL →',
                  style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextPrimary)),
            ),
          ],
        ],
      ),
    );
  }
}
