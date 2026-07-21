/// 表示「扫描文件夹」流程中扫描到的一个文件夹候选。
class FolderCandidateModel {
  const FolderCandidateModel({
    required this.path,
    required this.name,
    required this.bookCount,
  });

  /// 文件夹的完整路径（选中后用于递归扫描其中的书籍）。
  final String path;

  /// 展示用的文件夹名称（路径最后一段）。
  final String name;

  /// 该文件夹（含子目录）递归包含的受支持书籍数量，用于列表展示。
  final int bookCount;
}
