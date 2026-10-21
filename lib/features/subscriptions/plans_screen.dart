import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../shared/repository.dart';
import '../../shared/widgets.dart';

class PlansScreen extends StatefulWidget {
  final NovaRepository repo;
  const PlansScreen({super.key, required this.repo});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  late Future<List<DbRow>> data = widget.repo.plans();
  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return AsyncPane<List<DbRow>>(
      future: data,
      retry: () => setState(() => data = widget.repo.plans()),
      builder: (rows) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            s.t(
              'مساحة أوسع، بنفس الاحترام',
              'More possibilities. The same respect.',
            ),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            s.t(
              'الاكتشاف الأساسي والإعجاب والمحادثات المتبادلة وأدوات السلامة مجانية. لا يمكن شراء تجاوز خصوصية أي شخص.',
              'Core discovery, likes, mutual chats and safety tools are free. Privacy cannot be bypassed by paying.',
            ),
          ),
          const SizedBox(height: 24),
          if (rows.isEmpty)
            Text(
              s.t(
                'لم تُفعّل خطط مدفوعة بعد.',
                'No paid plans are enabled yet.',
              ),
            ),
          ...rows.map(
            (p) => Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.ar ? p['name_ar'] : p['name_en'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(s.ar ? p['description_ar'] : p['description_en']),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            s.t('الشراء غير مفعل', 'Purchases are not enabled'),
                          ),
                          content: Text(
                            s.t(
                              'يلزم إعداد منتجات المتجر والتحقق من المدفوعات على الخادم قبل عرض أسعار أو قبول الدفع.',
                              'Store products and server payment verification must be configured before displaying prices or accepting payment.',
                            ),
                          ),
                        ),
                      ),
                      child: Text(s.t('حالة التفعيل', 'Availability')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            s.t(
              'لا توجد إعلانات داخل المحادثات. لا تُباع علامة التوثيق.',
              'No ads in conversations. Verification is never sold.',
            ),
          ),
        ],
      ),
    );
  }
}
