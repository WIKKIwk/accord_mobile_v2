part of '../mobile_api.dart';

final List<CalculateOrderTemplate> _testModeCalculateOrderTemplates = [];
final List<CalculateMaterial> _testModeCalculateMaterials =
    List<CalculateMaterial>.from(_defaultCalculateMaterials());
const double kCalculateEdgeAllowanceMm = 15;
const double kCalculateMinMoldExtraMm = 50;
const double kCalculateAdhesiveGsmPerBond = 2.5;
const double _defaultPetDensityGCm3 = 1.400;
const double _defaultPpFilmDensityGCm3 = 0.905;
const double _defaultPeDensityGCm3 = 0.920;
