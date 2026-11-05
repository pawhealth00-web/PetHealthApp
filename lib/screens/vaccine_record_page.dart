import 'package:flutter/material.dart';

import 'medical_record_page.dart';

/// Keeps older navigation links working while opening the combined medical page.
class VaccineRecordPage extends StatelessWidget {
  const VaccineRecordPage({super.key, required this.petId, required this.petName});
  final String petId;
  final String petName;

  @override
  Widget build(BuildContext context) =>
      MedicalRecordPage(petId: petId, petName: petName);
}
