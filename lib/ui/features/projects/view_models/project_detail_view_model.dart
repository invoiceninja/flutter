import 'package:admin/data/models/domain/project.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';

/// Project detail VM is a typedef on the generic base — no entity-specific
/// derived state. What the record screen adds up from the project's tasks
/// (the standing card's figures, the chart) is watched by the screen itself;
/// promote this to a real subclass (mirror `ClientDetailViewModel`) if that
/// ever needs to outlive a rebuild.
typedef ProjectDetailViewModel = GenericDetailViewModel<Project>;
