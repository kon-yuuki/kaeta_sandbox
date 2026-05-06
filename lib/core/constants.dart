import 'package:flutter/material.dart';

const List<ButtonSegment<int>> prioritySegments = [
  ButtonSegment(value: 0, label: Text('目安でOK')),
  ButtonSegment(value: 1, label: Text('必ず条件を守る')),
];

const List<ButtonSegment<int>> budgetTypeSegments = [
  ButtonSegment(value: 0, label: Text('1つあたり')),
  ButtonSegment(value: 1, label: Text('100gあたり')),
];

const List<String> quantityPresets = [
  '未指定',
  '1/2',
  '1/4',
  '大容量',
  '少量',
];
