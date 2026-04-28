enum ApprovalStatus {
  pending,
  approved,
  rejected;

  static ApprovalStatus fromIndex(int index) => ApprovalStatus.values[index];
}
