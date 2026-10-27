import 'package:flutter/material.dart';
import 'package:projeto_final/core/models/agendamento_detalhado.dart';
import 'package:projeto_final/core/utils/mascaras.dart';
import 'package:projeto_final/features/home/widgets/agendamento_card.dart';
import 'package:table_calendar/table_calendar.dart';

class Calendario extends StatefulWidget {
  /// Consultas do paciente. Os dias que têm consulta ficam marcados e, ao
  /// selecionar um dia, as consultas dele aparecem abaixo do calendário.
  final List<AgendamentoDetalhado> agendamentos;

  const Calendario({super.key, this.agendamentos = const []});

  @override
  State<Calendario> createState() => _CalendarioState();
}

class _CalendarioState extends State<Calendario> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();

  CalendarFormat _calendarFormat = CalendarFormat.month;

  /// Consultas ativas de um dia, em ordem de horário.
  List<AgendamentoDetalhado> _doDia(DateTime dia) {
    return widget.agendamentos
        .where((c) => c.ativo)
        .where((c) => isSameDay(c.data, dia))
        .toList()
      ..sort((a, b) => a.data.compareTo(b.data));
  }

  @override
  Widget build(BuildContext context) {
    final consultasDoDia = _doDia(_selectedDate);
    final consultasDoDiaSemAtraso = consultasDoDia
        .where((consulta) => !consulta.data.isBefore(DateTime.now()))
        .toList();
    final consultasAtrasadas = consultasDoDia
        .where((consulta) => consulta.data.isBefore(DateTime.now()))
        .toList();
    final secondary = Theme.of(context).colorScheme.secondary;
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        const SizedBox(height: 15),

        // BOTÕES MÊS / SEMANA
        SizedBox(
          height: 45,
          child: Row(
            children: [
              Expanded(
                child: _buildCalendarButton(
                  context: context,
                  text: 'Mês',
                  icon: Icons.calendar_month,
                  selected: _calendarFormat == CalendarFormat.month,
                  onTap: () {
                    setState(() {
                      _calendarFormat = CalendarFormat.month;
                    });
                  },
                  left: true,
                ),
              ),

              Expanded(
                child: _buildCalendarButton(
                  context: context,
                  text: 'Semana',
                  icon: Icons.calendar_view_week,
                  selected: _calendarFormat == CalendarFormat.week,
                  onTap: () {
                    setState(() {
                      _calendarFormat = CalendarFormat.week;
                    });
                  },
                  left: false,
                ),
              ),
            ],
          ),
        ),

        // CALENDÁRIO
        TableCalendar(
          locale: 'pt_BR',

          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),

          focusedDay: _focusedDate,

          selectedDayPredicate: (day) {
            return isSameDay(_selectedDate, day);
          },

          calendarFormat: _calendarFormat,

          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDate = selectedDay;
              _focusedDate = focusedDay;
            });
          },

          onPageChanged: (focusedDay) {
            _focusedDate = focusedDay;
          },

          // Bolinha nos dias que têm consulta.
          eventLoader: _doDia,

          startingDayOfWeek: StartingDayOfWeek.monday,

          daysOfWeekHeight: 24,

          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),

          calendarStyle: CalendarStyle(
            outsideDaysVisible: true,
            markerMargin: const EdgeInsets.only(top: 1),

            // Dia de hoje (quando não é o selecionado) usa a secondary
            // com menos opacidade, pra não competir com o dia selecionado.
            todayDecoration: BoxDecoration(
              color: secondary.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
            ),

            markersMaxCount: 1,

            // Dia selecionado usa a cor secondary do tema.
            selectedDecoration: BoxDecoration(
              color: secondary,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;

              return Transform.translate(
                key: const ValueKey('appointment-marker-position'),
                offset: const Offset(0, -8),
                child: Container(
                  key: const ValueKey('appointment-marker'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSameDay(day, _selectedDate)
                        ? Colors.white
                        : primary,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),

        // CONSULTAS DO DIA SELECIONADO
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Consultas em ${formatarData(_selectedDate)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        if (consultasDoDia.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Nenhuma consulta neste dia.',
              style: TextStyle(
                fontSize: 14,
                color: primary.withValues(alpha: 0.7),
              ),
            ),
          )
        else ...[
          for (final consulta in consultasDoDiaSemAtraso) ...[
            AgendamentoCard(consulta: consulta),
            const SizedBox(height: 8),
          ],
          if (consultasAtrasadas.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Consultas atrasadas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            for (final consulta in consultasAtrasadas) ...[
              AgendamentoCard(consulta: consulta),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildCalendarButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required bool left,
  }) {
    final secondary = Theme.of(context).colorScheme.secondary;
    final surface = Theme.of(context).colorScheme.surface;

    return InkWell(
      onTap: onTap,

      child: Container(
        decoration: BoxDecoration(
          color: selected ? secondary : surface,

          border: Border.all(color: secondary, width: 1),

          borderRadius: BorderRadius.only(
            topLeft: left ? const Radius.circular(10) : Radius.zero,

            bottomLeft: left ? const Radius.circular(10) : Radius.zero,

            topRight: !left ? const Radius.circular(10) : Radius.zero,

            bottomRight: !left ? const Radius.circular(10) : Radius.zero,
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, size: 20, color: selected ? Colors.white : secondary),

            const SizedBox(width: 8),

            Text(
              text,

              style: TextStyle(
                color: selected ? Colors.white : secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
