// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'creator.dart';

class CreatorMapper extends ClassMapperBase<Creator> {
  CreatorMapper._();

  static CreatorMapper? _instance;
  static CreatorMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreatorMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Creator';

  static String _$id(Creator v) => v.id;
  static const Field<Creator, String> _f$id = Field('id', _$id);
  static String _$service(Creator v) => v.service;
  static const Field<Creator, String> _f$service = Field('service', _$service);
  static String? _$name(Creator v) => v.name;
  static const Field<Creator, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );
  static int _$favorited(Creator v) => v.favorited;
  static const Field<Creator, int> _f$favorited = Field(
    'favorited',
    _$favorited,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<Creator> fields = const {
    #id: _f$id,
    #service: _f$service,
    #name: _f$name,
    #favorited: _f$favorited,
  };

  static Creator _instantiate(DecodingData data) {
    return Creator(
      id: data.dec(_f$id),
      service: data.dec(_f$service),
      name: data.dec(_f$name),
      favorited: data.dec(_f$favorited),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Creator fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Creator>(map);
  }

  static Creator fromJson(String json) {
    return ensureInitialized().decodeJson<Creator>(json);
  }
}

mixin CreatorMappable {
  String toJson() {
    return CreatorMapper.ensureInitialized().encodeJson<Creator>(
      this as Creator,
    );
  }

  Map<String, dynamic> toMap() {
    return CreatorMapper.ensureInitialized().encodeMap<Creator>(
      this as Creator,
    );
  }

  CreatorCopyWith<Creator, Creator, Creator> get copyWith =>
      _CreatorCopyWithImpl<Creator, Creator>(
        this as Creator,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CreatorMapper.ensureInitialized().stringifyValue(this as Creator);
  }

  @override
  bool operator ==(Object other) {
    return CreatorMapper.ensureInitialized().equalsValue(
      this as Creator,
      other,
    );
  }

  @override
  int get hashCode {
    return CreatorMapper.ensureInitialized().hashValue(this as Creator);
  }
}

extension CreatorValueCopy<$R, $Out> on ObjectCopyWith<$R, Creator, $Out> {
  CreatorCopyWith<$R, Creator, $Out> get $asCreator =>
      $base.as((v, t, t2) => _CreatorCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CreatorCopyWith<$R, $In extends Creator, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, String? service, String? name, int? favorited});
  CreatorCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CreatorCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Creator, $Out>
    implements CreatorCopyWith<$R, Creator, $Out> {
  _CreatorCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Creator> $mapper =
      CreatorMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? service,
    Object? name = $none,
    int? favorited,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (service != null) #service: service,
      if (name != $none) #name: name,
      if (favorited != null) #favorited: favorited,
    }),
  );
  @override
  Creator $make(CopyWithData data) => Creator(
    id: data.get(#id, or: $value.id),
    service: data.get(#service, or: $value.service),
    name: data.get(#name, or: $value.name),
    favorited: data.get(#favorited, or: $value.favorited),
  );

  @override
  CreatorCopyWith<$R2, Creator, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _CreatorCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

