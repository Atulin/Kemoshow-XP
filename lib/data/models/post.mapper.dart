// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'post.dart';

class PostFileMapper extends ClassMapperBase<PostFile> {
  PostFileMapper._();

  static PostFileMapper? _instance;
  static PostFileMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PostFileMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'PostFile';

  static String? _$name(PostFile v) => v.name;
  static const Field<PostFile, String> _f$name = Field(
    'name',
    _$name,
    opt: true,
  );
  static String? _$path(PostFile v) => v.path;
  static const Field<PostFile, String> _f$path = Field(
    'path',
    _$path,
    opt: true,
  );

  @override
  final MappableFields<PostFile> fields = const {
    #name: _f$name,
    #path: _f$path,
  };

  static PostFile _instantiate(DecodingData data) {
    return PostFile(name: data.dec(_f$name), path: data.dec(_f$path));
  }

  @override
  final Function instantiate = _instantiate;

  static PostFile fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PostFile>(map);
  }

  static PostFile fromJson(String json) {
    return ensureInitialized().decodeJson<PostFile>(json);
  }
}

mixin PostFileMappable {
  String toJson() {
    return PostFileMapper.ensureInitialized().encodeJson<PostFile>(
      this as PostFile,
    );
  }

  Map<String, dynamic> toMap() {
    return PostFileMapper.ensureInitialized().encodeMap<PostFile>(
      this as PostFile,
    );
  }

  PostFileCopyWith<PostFile, PostFile, PostFile> get copyWith =>
      _PostFileCopyWithImpl<PostFile, PostFile>(
        this as PostFile,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PostFileMapper.ensureInitialized().stringifyValue(this as PostFile);
  }

  @override
  bool operator ==(Object other) {
    return PostFileMapper.ensureInitialized().equalsValue(
      this as PostFile,
      other,
    );
  }

  @override
  int get hashCode {
    return PostFileMapper.ensureInitialized().hashValue(this as PostFile);
  }
}

extension PostFileValueCopy<$R, $Out> on ObjectCopyWith<$R, PostFile, $Out> {
  PostFileCopyWith<$R, PostFile, $Out> get $asPostFile =>
      $base.as((v, t, t2) => _PostFileCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PostFileCopyWith<$R, $In extends PostFile, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, String? path});
  PostFileCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PostFileCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PostFile, $Out>
    implements PostFileCopyWith<$R, PostFile, $Out> {
  _PostFileCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PostFile> $mapper =
      PostFileMapper.ensureInitialized();
  @override
  $R call({Object? name = $none, Object? path = $none}) => $apply(
    FieldCopyWithData({
      if (name != $none) #name: name,
      if (path != $none) #path: path,
    }),
  );
  @override
  PostFile $make(CopyWithData data) => PostFile(
    name: data.get(#name, or: $value.name),
    path: data.get(#path, or: $value.path),
  );

  @override
  PostFileCopyWith<$R2, PostFile, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PostFileCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PostMapper extends ClassMapperBase<Post> {
  PostMapper._();

  static PostMapper? _instance;
  static PostMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PostMapper._());
      PostFileMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Post';

  static String _$id(Post v) => v.id;
  static const Field<Post, String> _f$id = Field('id', _$id);
  static String? _$user(Post v) => v.user;
  static const Field<Post, String> _f$user = Field('user', _$user, opt: true);
  static String? _$service(Post v) => v.service;
  static const Field<Post, String> _f$service = Field(
    'service',
    _$service,
    opt: true,
  );
  static String? _$title(Post v) => v.title;
  static const Field<Post, String> _f$title = Field(
    'title',
    _$title,
    opt: true,
  );
  static String? _$content(Post v) => v.content;
  static const Field<Post, String> _f$content = Field(
    'content',
    _$content,
    opt: true,
  );
  static PostFile? _$file(Post v) => v.file;
  static const Field<Post, PostFile> _f$file = Field('file', _$file, opt: true);
  static List<PostFile> _$attachments(Post v) => v.attachments;
  static const Field<Post, List<PostFile>> _f$attachments = Field(
    'attachments',
    _$attachments,
    opt: true,
    def: const [],
  );
  static String? _$published(Post v) => v.published;
  static const Field<Post, String> _f$published = Field(
    'published',
    _$published,
    opt: true,
  );
  static String? _$added(Post v) => v.added;
  static const Field<Post, String> _f$added = Field(
    'added',
    _$added,
    opt: true,
  );
  static bool _$sharedFile(Post v) => v.sharedFile;
  static const Field<Post, bool> _f$sharedFile = Field(
    'sharedFile',
    _$sharedFile,
    key: r'shared_file',
    opt: true,
    def: false,
  );

  @override
  final MappableFields<Post> fields = const {
    #id: _f$id,
    #user: _f$user,
    #service: _f$service,
    #title: _f$title,
    #content: _f$content,
    #file: _f$file,
    #attachments: _f$attachments,
    #published: _f$published,
    #added: _f$added,
    #sharedFile: _f$sharedFile,
  };

  static Post _instantiate(DecodingData data) {
    return Post(
      id: data.dec(_f$id),
      user: data.dec(_f$user),
      service: data.dec(_f$service),
      title: data.dec(_f$title),
      content: data.dec(_f$content),
      file: data.dec(_f$file),
      attachments: data.dec(_f$attachments),
      published: data.dec(_f$published),
      added: data.dec(_f$added),
      sharedFile: data.dec(_f$sharedFile),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Post fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Post>(map);
  }

  static Post fromJson(String json) {
    return ensureInitialized().decodeJson<Post>(json);
  }
}

mixin PostMappable {
  String toJson() {
    return PostMapper.ensureInitialized().encodeJson<Post>(this as Post);
  }

  Map<String, dynamic> toMap() {
    return PostMapper.ensureInitialized().encodeMap<Post>(this as Post);
  }

  PostCopyWith<Post, Post, Post> get copyWith =>
      _PostCopyWithImpl<Post, Post>(this as Post, $identity, $identity);
  @override
  String toString() {
    return PostMapper.ensureInitialized().stringifyValue(this as Post);
  }

  @override
  bool operator ==(Object other) {
    return PostMapper.ensureInitialized().equalsValue(this as Post, other);
  }

  @override
  int get hashCode {
    return PostMapper.ensureInitialized().hashValue(this as Post);
  }
}

extension PostValueCopy<$R, $Out> on ObjectCopyWith<$R, Post, $Out> {
  PostCopyWith<$R, Post, $Out> get $asPost =>
      $base.as((v, t, t2) => _PostCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PostCopyWith<$R, $In extends Post, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  PostFileCopyWith<$R, PostFile, PostFile>? get file;
  ListCopyWith<$R, PostFile, PostFileCopyWith<$R, PostFile, PostFile>>
  get attachments;
  $R call({
    String? id,
    String? user,
    String? service,
    String? title,
    String? content,
    PostFile? file,
    List<PostFile>? attachments,
    String? published,
    String? added,
    bool? sharedFile,
  });
  PostCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PostCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Post, $Out>
    implements PostCopyWith<$R, Post, $Out> {
  _PostCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Post> $mapper = PostMapper.ensureInitialized();
  @override
  PostFileCopyWith<$R, PostFile, PostFile>? get file =>
      $value.file?.copyWith.$chain((v) => call(file: v));
  @override
  ListCopyWith<$R, PostFile, PostFileCopyWith<$R, PostFile, PostFile>>
  get attachments => ListCopyWith(
    $value.attachments,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(attachments: v),
  );
  @override
  $R call({
    String? id,
    Object? user = $none,
    Object? service = $none,
    Object? title = $none,
    Object? content = $none,
    Object? file = $none,
    List<PostFile>? attachments,
    Object? published = $none,
    Object? added = $none,
    bool? sharedFile,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (user != $none) #user: user,
      if (service != $none) #service: service,
      if (title != $none) #title: title,
      if (content != $none) #content: content,
      if (file != $none) #file: file,
      if (attachments != null) #attachments: attachments,
      if (published != $none) #published: published,
      if (added != $none) #added: added,
      if (sharedFile != null) #sharedFile: sharedFile,
    }),
  );
  @override
  Post $make(CopyWithData data) => Post(
    id: data.get(#id, or: $value.id),
    user: data.get(#user, or: $value.user),
    service: data.get(#service, or: $value.service),
    title: data.get(#title, or: $value.title),
    content: data.get(#content, or: $value.content),
    file: data.get(#file, or: $value.file),
    attachments: data.get(#attachments, or: $value.attachments),
    published: data.get(#published, or: $value.published),
    added: data.get(#added, or: $value.added),
    sharedFile: data.get(#sharedFile, or: $value.sharedFile),
  );

  @override
  PostCopyWith<$R2, Post, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PostCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PostSearchResponseMapper extends ClassMapperBase<PostSearchResponse> {
  PostSearchResponseMapper._();

  static PostSearchResponseMapper? _instance;
  static PostSearchResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PostSearchResponseMapper._());
      PostMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'PostSearchResponse';

  static List<Post> _$posts(PostSearchResponse v) => v.posts;
  static const Field<PostSearchResponse, List<Post>> _f$posts = Field(
    'posts',
    _$posts,
    opt: true,
    def: const [],
  );
  static int _$count(PostSearchResponse v) => v.count;
  static const Field<PostSearchResponse, int> _f$count = Field(
    'count',
    _$count,
    opt: true,
    def: 0,
  );
  static int _$trueCount(PostSearchResponse v) => v.trueCount;
  static const Field<PostSearchResponse, int> _f$trueCount = Field(
    'trueCount',
    _$trueCount,
    key: r'true_count',
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<PostSearchResponse> fields = const {
    #posts: _f$posts,
    #count: _f$count,
    #trueCount: _f$trueCount,
  };

  static PostSearchResponse _instantiate(DecodingData data) {
    return PostSearchResponse(
      posts: data.dec(_f$posts),
      count: data.dec(_f$count),
      trueCount: data.dec(_f$trueCount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static PostSearchResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<PostSearchResponse>(map);
  }

  static PostSearchResponse fromJson(String json) {
    return ensureInitialized().decodeJson<PostSearchResponse>(json);
  }
}

mixin PostSearchResponseMappable {
  String toJson() {
    return PostSearchResponseMapper.ensureInitialized()
        .encodeJson<PostSearchResponse>(this as PostSearchResponse);
  }

  Map<String, dynamic> toMap() {
    return PostSearchResponseMapper.ensureInitialized()
        .encodeMap<PostSearchResponse>(this as PostSearchResponse);
  }

  PostSearchResponseCopyWith<
    PostSearchResponse,
    PostSearchResponse,
    PostSearchResponse
  >
  get copyWith =>
      _PostSearchResponseCopyWithImpl<PostSearchResponse, PostSearchResponse>(
        this as PostSearchResponse,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PostSearchResponseMapper.ensureInitialized().stringifyValue(
      this as PostSearchResponse,
    );
  }

  @override
  bool operator ==(Object other) {
    return PostSearchResponseMapper.ensureInitialized().equalsValue(
      this as PostSearchResponse,
      other,
    );
  }

  @override
  int get hashCode {
    return PostSearchResponseMapper.ensureInitialized().hashValue(
      this as PostSearchResponse,
    );
  }
}

extension PostSearchResponseValueCopy<$R, $Out>
    on ObjectCopyWith<$R, PostSearchResponse, $Out> {
  PostSearchResponseCopyWith<$R, PostSearchResponse, $Out>
  get $asPostSearchResponse => $base.as(
    (v, t, t2) => _PostSearchResponseCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class PostSearchResponseCopyWith<
  $R,
  $In extends PostSearchResponse,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Post, PostCopyWith<$R, Post, Post>> get posts;
  $R call({List<Post>? posts, int? count, int? trueCount});
  PostSearchResponseCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _PostSearchResponseCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, PostSearchResponse, $Out>
    implements PostSearchResponseCopyWith<$R, PostSearchResponse, $Out> {
  _PostSearchResponseCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<PostSearchResponse> $mapper =
      PostSearchResponseMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Post, PostCopyWith<$R, Post, Post>> get posts =>
      ListCopyWith(
        $value.posts,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(posts: v),
      );
  @override
  $R call({List<Post>? posts, int? count, int? trueCount}) => $apply(
    FieldCopyWithData({
      if (posts != null) #posts: posts,
      if (count != null) #count: count,
      if (trueCount != null) #trueCount: trueCount,
    }),
  );
  @override
  PostSearchResponse $make(CopyWithData data) => PostSearchResponse(
    posts: data.get(#posts, or: $value.posts),
    count: data.get(#count, or: $value.count),
    trueCount: data.get(#trueCount, or: $value.trueCount),
  );

  @override
  PostSearchResponseCopyWith<$R2, PostSearchResponse, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _PostSearchResponseCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CreatorPostsResponseMapper extends ClassMapperBase<CreatorPostsResponse> {
  CreatorPostsResponseMapper._();

  static CreatorPostsResponseMapper? _instance;
  static CreatorPostsResponseMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreatorPostsResponseMapper._());
      PostMapper.ensureInitialized();
      CreatorPostsPropsMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CreatorPostsResponse';

  static List<Post> _$results(CreatorPostsResponse v) => v.results;
  static const Field<CreatorPostsResponse, List<Post>> _f$results = Field(
    'results',
    _$results,
    opt: true,
    def: const [],
  );
  static CreatorPostsProps? _$props(CreatorPostsResponse v) => v.props;
  static const Field<CreatorPostsResponse, CreatorPostsProps> _f$props = Field(
    'props',
    _$props,
    opt: true,
  );

  @override
  final MappableFields<CreatorPostsResponse> fields = const {
    #results: _f$results,
    #props: _f$props,
  };

  static CreatorPostsResponse _instantiate(DecodingData data) {
    return CreatorPostsResponse(
      results: data.dec(_f$results),
      props: data.dec(_f$props),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CreatorPostsResponse fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreatorPostsResponse>(map);
  }

  static CreatorPostsResponse fromJson(String json) {
    return ensureInitialized().decodeJson<CreatorPostsResponse>(json);
  }
}

mixin CreatorPostsResponseMappable {
  String toJson() {
    return CreatorPostsResponseMapper.ensureInitialized()
        .encodeJson<CreatorPostsResponse>(this as CreatorPostsResponse);
  }

  Map<String, dynamic> toMap() {
    return CreatorPostsResponseMapper.ensureInitialized()
        .encodeMap<CreatorPostsResponse>(this as CreatorPostsResponse);
  }

  CreatorPostsResponseCopyWith<
    CreatorPostsResponse,
    CreatorPostsResponse,
    CreatorPostsResponse
  >
  get copyWith =>
      _CreatorPostsResponseCopyWithImpl<
        CreatorPostsResponse,
        CreatorPostsResponse
      >(this as CreatorPostsResponse, $identity, $identity);
  @override
  String toString() {
    return CreatorPostsResponseMapper.ensureInitialized().stringifyValue(
      this as CreatorPostsResponse,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreatorPostsResponseMapper.ensureInitialized().equalsValue(
      this as CreatorPostsResponse,
      other,
    );
  }

  @override
  int get hashCode {
    return CreatorPostsResponseMapper.ensureInitialized().hashValue(
      this as CreatorPostsResponse,
    );
  }
}

extension CreatorPostsResponseValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreatorPostsResponse, $Out> {
  CreatorPostsResponseCopyWith<$R, CreatorPostsResponse, $Out>
  get $asCreatorPostsResponse => $base.as(
    (v, t, t2) => _CreatorPostsResponseCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CreatorPostsResponseCopyWith<
  $R,
  $In extends CreatorPostsResponse,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, Post, PostCopyWith<$R, Post, Post>> get results;
  CreatorPostsPropsCopyWith<$R, CreatorPostsProps, CreatorPostsProps>?
  get props;
  $R call({List<Post>? results, CreatorPostsProps? props});
  CreatorPostsResponseCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreatorPostsResponseCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreatorPostsResponse, $Out>
    implements CreatorPostsResponseCopyWith<$R, CreatorPostsResponse, $Out> {
  _CreatorPostsResponseCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreatorPostsResponse> $mapper =
      CreatorPostsResponseMapper.ensureInitialized();
  @override
  ListCopyWith<$R, Post, PostCopyWith<$R, Post, Post>> get results =>
      ListCopyWith(
        $value.results,
        (v, t) => v.copyWith.$chain(t),
        (v) => call(results: v),
      );
  @override
  CreatorPostsPropsCopyWith<$R, CreatorPostsProps, CreatorPostsProps>?
  get props => $value.props?.copyWith.$chain((v) => call(props: v));
  @override
  $R call({List<Post>? results, Object? props = $none}) => $apply(
    FieldCopyWithData({
      if (results != null) #results: results,
      if (props != $none) #props: props,
    }),
  );
  @override
  CreatorPostsResponse $make(CopyWithData data) => CreatorPostsResponse(
    results: data.get(#results, or: $value.results),
    props: data.get(#props, or: $value.props),
  );

  @override
  CreatorPostsResponseCopyWith<$R2, CreatorPostsResponse, $Out2>
  $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _CreatorPostsResponseCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CreatorPostsPropsMapper extends ClassMapperBase<CreatorPostsProps> {
  CreatorPostsPropsMapper._();

  static CreatorPostsPropsMapper? _instance;
  static CreatorPostsPropsMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CreatorPostsPropsMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CreatorPostsProps';

  static int? _$count(CreatorPostsProps v) => v.count;
  static const Field<CreatorPostsProps, int> _f$count = Field(
    'count',
    _$count,
    opt: true,
  );

  @override
  final MappableFields<CreatorPostsProps> fields = const {#count: _f$count};

  static CreatorPostsProps _instantiate(DecodingData data) {
    return CreatorPostsProps(count: data.dec(_f$count));
  }

  @override
  final Function instantiate = _instantiate;

  static CreatorPostsProps fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CreatorPostsProps>(map);
  }

  static CreatorPostsProps fromJson(String json) {
    return ensureInitialized().decodeJson<CreatorPostsProps>(json);
  }
}

mixin CreatorPostsPropsMappable {
  String toJson() {
    return CreatorPostsPropsMapper.ensureInitialized()
        .encodeJson<CreatorPostsProps>(this as CreatorPostsProps);
  }

  Map<String, dynamic> toMap() {
    return CreatorPostsPropsMapper.ensureInitialized()
        .encodeMap<CreatorPostsProps>(this as CreatorPostsProps);
  }

  CreatorPostsPropsCopyWith<
    CreatorPostsProps,
    CreatorPostsProps,
    CreatorPostsProps
  >
  get copyWith =>
      _CreatorPostsPropsCopyWithImpl<CreatorPostsProps, CreatorPostsProps>(
        this as CreatorPostsProps,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CreatorPostsPropsMapper.ensureInitialized().stringifyValue(
      this as CreatorPostsProps,
    );
  }

  @override
  bool operator ==(Object other) {
    return CreatorPostsPropsMapper.ensureInitialized().equalsValue(
      this as CreatorPostsProps,
      other,
    );
  }

  @override
  int get hashCode {
    return CreatorPostsPropsMapper.ensureInitialized().hashValue(
      this as CreatorPostsProps,
    );
  }
}

extension CreatorPostsPropsValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CreatorPostsProps, $Out> {
  CreatorPostsPropsCopyWith<$R, CreatorPostsProps, $Out>
  get $asCreatorPostsProps => $base.as(
    (v, t, t2) => _CreatorPostsPropsCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CreatorPostsPropsCopyWith<
  $R,
  $In extends CreatorPostsProps,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? count});
  CreatorPostsPropsCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CreatorPostsPropsCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CreatorPostsProps, $Out>
    implements CreatorPostsPropsCopyWith<$R, CreatorPostsProps, $Out> {
  _CreatorPostsPropsCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CreatorPostsProps> $mapper =
      CreatorPostsPropsMapper.ensureInitialized();
  @override
  $R call({Object? count = $none}) =>
      $apply(FieldCopyWithData({if (count != $none) #count: count}));
  @override
  CreatorPostsProps $make(CopyWithData data) =>
      CreatorPostsProps(count: data.get(#count, or: $value.count));

  @override
  CreatorPostsPropsCopyWith<$R2, CreatorPostsProps, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CreatorPostsPropsCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

