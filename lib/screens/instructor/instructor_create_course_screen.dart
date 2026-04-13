// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:image_picker/image_picker.dart';
import '../../core/design/app_colors.dart';
import '../../core/design/app_radius.dart';
import '../../core/navigation/route_names.dart';
import '../../services/courses_service.dart';
import '../../services/profile_service.dart';
import '../../services/teacher_dashboard_service.dart';
// import '../../services/upload_service.dart';
import '../../widgets/instructor_bottom_nav.dart';

/// Instructor – Create new course. Uses POST /api/admin/courses (TEACHER_CREATE_COURSE_API).
class InstructorCreateCourseScreen extends StatefulWidget {
  const InstructorCreateCourseScreen({super.key});

  @override
  State<InstructorCreateCourseScreen> createState() =>
      _InstructorCreateCourseScreenState();
}

class _InstructorCreateCourseScreenState
    extends State<InstructorCreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thumbnailController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _discountPriceController = TextEditingController();
  final _durationController = TextEditingController(text: '0');

  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _selectedCategoryId;
  String _level = 'beginner';
  // File? _selectedThumbnail;
  // bool _isUploadingThumbnail = false;
  // final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _thumbnailController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // Future<void> _pickAndUploadThumbnail() async {
  //   try {
  //     final source = await showModalBottomSheet<ImageSource>(
  //       context: context,
  //       builder: (ctx) => SafeArea(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             ListTile(
  //               leading: const Icon(Icons.camera_alt, color: AppColors.purple),
  //               title: Text(
  //                 Localizations.localeOf(context).languageCode == 'ar'
  //                     ? 'الكاميرا'
  //                     : 'Camera',
  //                 style: GoogleFonts.cairo(),
  //               ),
  //               onTap: () => Navigator.pop(ctx, ImageSource.camera),
  //             ),
  //             ListTile(
  //               leading:
  //                   const Icon(Icons.photo_library, color: AppColors.purple),
  //               title: Text(
  //                 Localizations.localeOf(context).languageCode == 'ar'
  //                     ? 'المعرض'
  //                     : 'Gallery',
  //                 style: GoogleFonts.cairo(),
  //               ),
  //               onTap: () => Navigator.pop(ctx, ImageSource.gallery),
  //             ),
  //           ],
  //         ),
  //       ),
  //     );
  //     if (source == null) return;
  //
  //     final XFile? image = await _imagePicker.pickImage(
  //       source: source,
  //       imageQuality: 85,
  //       maxWidth: 1024,
  //       maxHeight: 1024,
  //     );
  //     if (image == null || !mounted) return;
  //
  //     setState(() {
  //       _selectedThumbnail = File(image.path);
  //       _isUploadingThumbnail = true;
  //     });
  //
  //     final url = await UploadService.instance.uploadImage(File(image.path));
  //     if (mounted) {
  //       setState(() {
  //         _thumbnailController.text = url;
  //         _isUploadingThumbnail = false;
  //       });
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isUploadingThumbnail = false);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             e.toString().replaceFirst('Exception: ', ''),
  //           ),
  //           backgroundColor: AppColors.destructive,
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _errorMessage = null;
    });
    try {
      final categories = await CoursesService.instance.getCategories(
        useAdmin: true,
      );
      if (mounted) {
        setState(() {
          _categories = categories;
          _isLoadingCategories = false;
          if (_categories.isNotEmpty && _selectedCategoryId == null) {
            _selectedCategoryId = _categories[0]['id']?.toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _categories = [];
          _isLoadingCategories = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final title = _titleController.text.trim();
    if (title.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'العنوان يجب أن يكون 3 أحرف على الأقل'
                : 'Title must be at least 3 characters',
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }
    final categoryId = _selectedCategoryId;
    if (categoryId == null || categoryId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'يرجى اختيار الفئة'
                : 'Please select a category',
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    String? instructorId;
    try {
      final profile = await ProfileService.instance.getProfile();
      instructorId = profile['id']?.toString();
    } catch (_) {}
    if (instructorId == null || instructorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'تعذر الحصول على بيانات المستخدم'
                : 'Could not get user profile',
          ),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final price = double.tryParse(_priceController.text) ?? 0;
      final discountPrice = double.tryParse(_discountPriceController.text);
      final duration = int.tryParse(_durationController.text) ?? 0;

      await TeacherDashboardService.instance.createCourse(
        title: title,
        categoryId: categoryId,
        instructorId: instructorId,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        thumbnail: _thumbnailController.text.trim().isEmpty
            ? null
            : _thumbnailController.text.trim(),
        price: price > 0 ? price : null,
        discountPrice:
            discountPrice != null && discountPrice > 0 ? discountPrice : null,
        level: _level,
        duration: duration,
        status: 'draft',
        isFeatured: false,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم إنشاء الدورة بنجاح. بانتظار الموافقة.'
                  : 'Course created successfully. Pending approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        context.go(RouteNames.instructorCourses);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.beige,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context, isAr),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              border: Border.all(
                                color: AppColors.destructive.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: AppColors.destructive, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14,
                                      color: AppColors.destructive,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        _buildCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(isAr ? 'العنوان *' : 'Title *'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _titleController,
                                textAlign:
                                    isAr ? TextAlign.right : TextAlign.left,
                                textDirection: isAr
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                decoration: InputDecoration(
                                  hintText: isAr
                                      ? 'أدخل عنوان الدورة (3-255 حرف)'
                                      : 'Enter course title (3-255 chars)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().length < 3) {
                                    return isAr
                                        ? '3 أحرف على الأقل'
                                        : 'At least 3 characters';
                                  }
                                  return null;
                                },
                                maxLength: 255,
                              ),
                              const SizedBox(height: 16),
                              _buildLabel(isAr ? 'الوصف' : 'Description'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _descriptionController,
                                textAlign:
                                    isAr ? TextAlign.right : TextAlign.left,
                                textDirection: isAr
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: isAr
                                      ? 'وصف مختصر عن محتوى الدورة'
                                      : 'Brief description of course content',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel(
                                  isAr ? 'صورة الغلاف' : 'Thumbnail URL'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _thumbnailController,
                                textAlign:
                                    isAr ? TextAlign.right : TextAlign.left,
                                textDirection: isAr
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                decoration: InputDecoration(
                                  hintText: isAr
                                      ? 'رابط صورة الغلاف (اختياري)'
                                      : 'Cover image URL (optional)',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildLabel(isAr ? 'الفئة *' : 'Category *'),
                              const SizedBox(height: 8),
                              _isLoadingCategories
                                  ? const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.purple,
                                        ),
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _selectedCategoryId,
                                      isExpanded: true,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.purple,
                                      ),
                                      dropdownColor: Colors.white,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                      ),
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        color: AppColors.foreground,
                                      ),
                                      items: _categories.map((c) {
                                        final id = c['id']?.toString() ?? '';
                                        final name = (isAr
                                                    ? (c['nameAr'] ??
                                                        c['name_ar'] ??
                                                        c['name'])
                                                    : (c['name'] ??
                                                        c['nameAr'] ??
                                                        c['name_ar']))
                                                ?.toString() ??
                                            id;
                                        return DropdownMenuItem(
                                          value: id,
                                          child: Align(
                                            alignment: isAr
                                                ? Alignment.centerRight
                                                : Alignment.centerLeft,
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textDirection: isAr
                                                  ? TextDirection.rtl
                                                  : TextDirection.ltr,
                                              style: GoogleFonts.cairo(
                                                fontSize: 14,
                                                color: AppColors.foreground,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (v) => setState(
                                          () => _selectedCategoryId = v),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return isAr
                                              ? 'اختر الفئة'
                                              : 'Select category';
                                        }
                                        return null;
                                      },
                                    ),
                              const SizedBox(height: 16),
                              _buildLabel(isAr ? 'المستوى' : 'Level'),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _level,
                                isExpanded: true,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.purple,
                                ),
                                dropdownColor: Colors.white,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'beginner',
                                    child: Text(
                                      isAr ? 'مبتدئ' : 'Beginner',
                                      style: GoogleFonts.cairo(),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'intermediate',
                                    child: Text(
                                      isAr ? 'متوسط' : 'Intermediate',
                                      style: GoogleFonts.cairo(),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'advanced',
                                    child: Text(
                                      isAr ? 'متقدم' : 'Advanced',
                                      style: GoogleFonts.cairo(),
                                    ),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _level = v ?? 'beginner'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(isAr ? 'السعر' : 'Price'),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _priceController,
                                          textAlign: isAr
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[\d.]'),
                                            ),
                                          ],
                                          decoration: InputDecoration(
                                            hintText: '0',
                                            suffixText: isAr ? 'ج.م' : 'EGP',
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(
                                            isAr ? 'سعر الخصم' : 'Discount'),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _discountPriceController,
                                          textAlign: isAr
                                              ? TextAlign.right
                                              : TextAlign.left,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(
                                            decimal: true,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                              RegExp(r'[\d.]'),
                                            ),
                                          ],
                                          decoration: InputDecoration(
                                            hintText: '-',
                                            suffixText: isAr ? 'ج.م' : 'EGP',
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildLabel(
                                  isAr ? 'المدة (دقيقة)' : 'Duration (min)'),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _durationController,
                                textAlign:
                                    isAr ? TextAlign.right : TextAlign.left,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  hintText: '0',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.button),
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          isAr
                                              ? 'إنشاء الدورة'
                                              : 'Create Course',
                                          style: GoogleFonts.cairo(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isAr
                              ? 'ستُنشأ الدورة بحالة "مسودة" وستحتاج موافقة الأدمن للنشر.'
                              : 'Course will be created as draft and needs admin approval to publish.',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppColors.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const InstructorBottomNav(activeTab: 'create'),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.foreground,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.purple.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildHeader(BuildContext context, bool isAr) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C52B3), Color(0xFF093F8A)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.largeCard),
          bottomRight: Radius.circular(AppRadius.largeCard),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go(RouteNames.instructorHome),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isAr ? 'إنشاء دورة' : 'Create Course',
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
