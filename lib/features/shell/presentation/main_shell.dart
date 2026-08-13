import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/enums/app_role.dart';
import '../../../core/models/app_session.dart';
import '../../attendance/presentation/attendance_page.dart';
import '../../dashboard/presentation/fgg_dashboard_page.dart';
import '../../heatmap/presentation/heatmap_page.dart';
import '../../home/presentation/home_page.dart';
import '../../leave/presentation/leave_approval_page.dart';
import '../../leave/presentation/leave_page.dart';
import '../../network/presentation/network_page.dart';
import '../../profile/presentation/profile_page.dart';
import '../../survey/presentation/survey_page.dart';
import '../../wfh/presentation/wfh_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session!;
    final destinations = _destinationsFor(session);

    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(destinations[_currentIndex].label),
            Text(
              '${session.userName} - ${session.role.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (widget.controller.canSwitchRolesForSession(session))
            PopupMenuButton<AppRole>(
              tooltip: 'Ganti role testing',
              initialValue: session.role,
              onSelected: (role) {
                widget.controller.switchRole(role);
                setState(() => _currentIndex = 0);
              },
              itemBuilder: (context) {
                return widget.controller
                    .switchableRolesForSession(session)
                    .map((role) {
                  return PopupMenuItem<AppRole>(
                    value: role,
                    child: Text(role.label),
                  );
                }).toList();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      session.areaName,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  session.areaName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.controller.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: destinations.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: destinations.length > 5
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: destinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  List<_NavItem> _destinationsFor(AppSession session) {
    switch (session.role) {
      case AppRole.areaManager:
        return [
          _NavItem(
            label: 'Home',
            icon: Icons.home_rounded,
            page: HomePage(
              session: session,
              controller: widget.controller,
              onRefresh: () =>
                  widget.controller.refreshHomeDataForSession(session),
              onOpenAttendance: () => _selectDestination('Absensi'),
              onOpenWfa: () => _openStandalonePage(
                title: 'WFA',
                child: WfhPage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              onOpenLeave: () => _openStandalonePage(
                title: 'Cuti / Izin',
                child: LeavePage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              homeMenus: [
                HomeMenuShortcut(
                  icon: Icons.laptop_mac_rounded,
                  title: 'WFA',
                  subtitle: 'Buka aktivitas WFA langsung dari Home.',
                  onTap: () => _openStandalonePage(
                    title: 'WFA',
                    child: WfhPage(
                      session: session,
                      controller: widget.controller,
                    ),
                  ),
                ),
                HomeMenuShortcut(
                  icon: Icons.event_note_rounded,
                  title: 'Cuti / Izin',
                  subtitle: 'Buka form pengajuan cuti atau izin.',
                  onTap: () => _openStandalonePage(
                    title: 'Cuti / Izin',
                    child: LeavePage(
                      session: session,
                      controller: widget.controller,
                    ),
                  ),
                ),
                _surveyShortcut(session),
              ],
            ),
          ),
          _NavItem(
            label: 'Absensi',
            icon: Icons.fingerprint_rounded,
            page: AttendancePage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Dashboard',
            icon: Icons.query_stats_rounded,
            page: FieldDashboardPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Jaringan',
            icon: Icons.hub_rounded,
            page: NetworkPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Heat Map',
            icon: Icons.map_rounded,
            page: HeatMapPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Akun',
            icon: Icons.person_rounded,
            page: ProfilePage(
              session: session,
              controller: widget.controller,
            ),
          ),
        ];
      case AppRole.fgg:
        return [
          _NavItem(
            label: 'Home',
            icon: Icons.home_rounded,
            page: HomePage(
              session: session,
              controller: widget.controller,
              onRefresh: () =>
                  widget.controller.refreshHomeDataForSession(session),
              onOpenWfa: () => _openStandalonePage(
                title: 'WFA',
                child: WfhPage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              onOpenLeave: () => _openStandalonePage(
                title: 'Cuti / Izin',
                child: LeavePage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              onOpenNetwork: () => _selectDestination('Jaringan'),
              homeMenus: [
                _surveyShortcut(session),
              ],
            ),
          ),
          _NavItem(
            label: 'Dashboard',
            icon: Icons.query_stats_rounded,
            page: FieldDashboardPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Jaringan',
            icon: Icons.storefront_rounded,
            page: NetworkPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Heat Map',
            icon: Icons.map_rounded,
            page: HeatMapPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Akun',
            icon: Icons.person_rounded,
            page: ProfilePage(
              session: session,
              controller: widget.controller,
            ),
          ),
        ];
      case AppRole.staff:
        return [
          _NavItem(
            label: 'Home',
            icon: Icons.home_rounded,
            page: HomePage(
              session: session,
              controller: widget.controller,
              onRefresh: () =>
                  widget.controller.refreshHomeDataForSession(session),
              onOpenAttendance: () => _selectDestination('Absensi'),
              onOpenWfa: () => _selectDestination('WFA'),
              onOpenLeave: () => _selectDestination('Cuti'),
              homeMenus: [
                _surveyShortcut(session),
              ],
            ),
          ),
          _NavItem(
            label: 'Absensi',
            icon: Icons.fingerprint_rounded,
            page: AttendancePage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'WFA',
            icon: Icons.laptop_mac_rounded,
            page: WfhPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Cuti',
            icon: Icons.event_note_rounded,
            page: LeavePage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Akun',
            icon: Icons.person_rounded,
            page: ProfilePage(
              session: session,
              controller: widget.controller,
            ),
          ),
        ];
      case AppRole.spv:
        return [
          _NavItem(
            label: 'Home',
            icon: Icons.home_rounded,
            page: HomePage(
              session: session,
              controller: widget.controller,
              onRefresh: () =>
                  widget.controller.refreshHomeDataForSession(session),
              onOpenAttendance: () => _selectDestination('Absensi'),
              onOpenWfa: () => _openStandalonePage(
                title: 'WFA',
                child: WfhPage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              onOpenLeave: () => _openStandalonePage(
                title: 'Cuti / Izin',
                child: LeavePage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              homeMenus: [
                HomeMenuShortcut(
                  icon: Icons.laptop_mac_rounded,
                  title: 'WFA',
                  subtitle: 'Buka aktivitas WFA langsung dari Home.',
                  onTap: () => _openStandalonePage(
                    title: 'WFA',
                    child: WfhPage(
                      session: session,
                      controller: widget.controller,
                    ),
                  ),
                ),
                HomeMenuShortcut(
                  icon: Icons.event_note_rounded,
                  title: 'Cuti / Izin',
                  subtitle: 'Buka form pengajuan cuti atau izin.',
                  onTap: () => _openStandalonePage(
                    title: 'Cuti / Izin',
                    child: LeavePage(
                      session: session,
                      controller: widget.controller,
                    ),
                  ),
                ),
                _surveyShortcut(session),
              ],
            ),
          ),
          _NavItem(
            label: 'Absensi',
            icon: Icons.fingerprint_rounded,
            page: AttendancePage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Approval',
            icon: Icons.fact_check_rounded,
            page: LeaveApprovalPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Akun',
            icon: Icons.person_rounded,
            page: ProfilePage(
              session: session,
              controller: widget.controller,
            ),
          ),
        ];
      case AppRole.management:
        return [
          _NavItem(
            label: 'Home',
            icon: Icons.home_rounded,
            page: HomePage(
              session: session,
              controller: widget.controller,
              onRefresh: () =>
                  widget.controller.refreshHomeDataForSession(session),
              onOpenAttendance: () => _selectDestination('Absensi'),
              onOpenWfa: () => _openStandalonePage(
                title: 'WFA',
                child: WfhPage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              onOpenLeave: () => _openStandalonePage(
                title: 'Cuti / Izin',
                child: LeavePage(
                  session: session,
                  controller: widget.controller,
                ),
              ),
              homeMenus: [
                HomeMenuShortcut(
                  icon: Icons.laptop_mac_rounded,
                  title: 'WFA',
                  subtitle: 'Buka aktivitas WFA langsung dari Home.',
                  onTap: () => _openStandalonePage(
                    title: 'WFA',
                    child: WfhPage(
                      session: session,
                      controller: widget.controller,
                    ),
                  ),
                ),
                HomeMenuShortcut(
                  icon: Icons.event_note_rounded,
                  title: 'Cuti / Izin',
                  subtitle: 'Buka form pengajuan cuti atau izin.',
                  onTap: () => _openStandalonePage(
                    title: 'Cuti / Izin',
                    child: LeavePage(
                      session: session,
                      controller: widget.controller,
                    ),
                  ),
                ),
                _surveyShortcut(session),
              ],
            ),
          ),
          _NavItem(
            label: 'Absensi',
            icon: Icons.fingerprint_rounded,
            page: AttendancePage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Approval',
            icon: Icons.fact_check_rounded,
            page: LeaveApprovalPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Jaringan',
            icon: Icons.hub_rounded,
            page: NetworkPage(
              session: session,
              controller: widget.controller,
            ),
          ),
          _NavItem(
            label: 'Akun',
            icon: Icons.person_rounded,
            page: ProfilePage(
              session: session,
              controller: widget.controller,
            ),
          ),
        ];
    }
  }

  HomeMenuShortcut _surveyShortcut(AppSession session) {
    return HomeMenuShortcut(
      icon: Icons.assignment_rounded,
      title: 'Survey',
      subtitle: 'Isi Survey Kios atau Survey Harga dari satu menu.',
      onTap: () => _openStandalonePage(
        title: 'Survey',
        child: SurveyPage(
          session: session,
          controller: widget.controller,
        ),
      ),
    );
  }

  void _selectDestination(String label) {
    final session = widget.controller.session;
    if (session == null) {
      return;
    }

    final destinations = _destinationsFor(session);
    final index = destinations.indexWhere((item) => item.label == label);
    if (index == -1) {
      return;
    }

    setState(() => _currentIndex = index);
  }

  Future<void> _openStandalonePage({
    required String title,
    required Widget child,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: child,
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}
