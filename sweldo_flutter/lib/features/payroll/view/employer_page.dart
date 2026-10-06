import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/shell/page_frame.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../bloc/schedules/schedules_bloc.dart';
import 'widgets/payroll_form.dart';
import 'widgets/schedule_list.dart';

class EmployerPage extends StatelessWidget {
  const EmployerPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Recent payrolls appear only once there is something to show.
    final hasHistory = context.select(
      (SchedulesBloc b) =>
          b.state.schedules.isNotEmpty || b.state.notice != null,
    );
    final twoColumns = context.up(Breakpoint.lg) && hasHistory;

    Widget list = const ScheduleList();
    if (!SwMotion.reduced(context)) {
      list = list
          .animate()
          .fadeIn(duration: SwMotion.deliberate)
          .slideX(begin: 0.04, end: 0, curve: SwMotion.enter);
    }

    final Widget body;
    if (twoColumns) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(flex: 7, child: PayrollForm()),
          const SizedBox(width: SwSpace.xl),
          Expanded(flex: 5, child: list),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PayrollForm(),
          if (hasHistory) ...[const SizedBox(height: SwSpace.xl), list],
        ],
      );
    }

    return PageFrame(
      title: 'Pay your team',
      description:
          'Lock a payroll schedule once. Each payout unlocks on its payday '
          'and settles itself.',
      child: body,
    );
  }
}
