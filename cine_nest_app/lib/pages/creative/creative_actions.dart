import 'package:cine_nest/pages/creative/models/content_block.dart';
import 'package:cine_nest/pages/kazumi_home/widgets/source_sheet.dart';
import 'package:cine_nest/router/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> handleCreativeAction(
  BuildContext context,
  MicroAction action, {
  String? fallbackTitle,
}) async {
  switch (action.type) {
    case 'openPoster':
    case 'openResourcePoster':
      Get.toNamed(Routes.creativePoster, arguments: action.data);
      break;
    case 'resolveAndPlay':
      _openSourceSheet(context, action, fallbackTitle: fallbackTitle);
      break;
    default:
      break;
  }
}

void _openSourceSheet(
  BuildContext context,
  MicroAction action, {
  String? fallbackTitle,
}) {
  final title = action
      .str(
        'title',
        (fallbackTitle?.trim().isNotEmpty ?? false)
            ? fallbackTitle!.trim()
            : action.str('episode_name', action.str('line_name')),
      )
      .trim();
  if (title.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('缺少影片标题，无法搜索')));
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 3 / 4,
    ),
    builder: (_) => SourceSheet(title: title),
  );
}
