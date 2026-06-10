import { useState } from 'react'
import { format, parseISO, isAfter } from 'date-fns'
import { de } from 'date-fns/locale'
import { useStore } from '../store'
import {
  ComposedChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
  Cell,
  PieChart,
  Pie,
  AreaChart,
  Area,
} from 'recharts'

const fmt = (v, currency = 'CHF') =>
  new Intl.NumberFormat('de-CH', { maximumFractionDigits: 0 }).format(v || 0) +
  ' ' +
  currency

const pct = (v, total) =>
  total > 0 ? ((v / total) * 100).toFixed(1) + '%' : '0%'

const monthLabel = (m) => {
  try {
    return format(parseISO(m + '-01'), 'MMM yy', { locale: de })
  } catch {
    return m
  }
}
const fullMonthLabel = (m) => {
  try {
    return format(parseISO(m + '-01'), 'MMMM yyyy', { locale: de })
  } catch {
    return m
  }
}

const today = format(new Date(), 'yyyy-MM')

const BudgetTooltip = ({ active, payload, label, currency }) => {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-3 text-xs">
      <div className="font-semibold text-gray-700 mb-2">{label}</div>
      {payload.map((p) => (
        <div key={p.name} className="flex items-center gap-2 mb-0.5">
          <div className="w-2 h-2 rounded-full" style={{ background: p.color || p.fill }} />
          <span className="text-gray-500">{p.name}:</span>
          <span className="font-medium text-gray-800">
            {typeof p.value === 'number'
              ? new Intl.NumberFormat('de-CH', { maximumFractionDigits: 0 }).format(p.value)
              : p.value}{' '}
            {currency}
          </span>
        </div>
      ))}
    </div>
  )
}

function KPICard({ label, value, sub, color = 'indigo', trend }) {
  const colors = {
    indigo: 'bg-indigo-50 text-indigo-700',
    green: 'bg-green-50 text-green-700',
    amber: 'bg-amber-50 text-amber-700',
    red: 'bg-red-50 text-red-700',
    gray: 'bg-gray-50 text-gray-700',
  }
  return (
    <div className="bg-white rounded-2xl border border-gray-100 p-5">
      <div className="text-xs font-medium text-gray-400 mb-2">{label}</div>
      <div className={`text-xl font-bold ${colors[color].split(' ')[1]}`}>{value}</div>
      {sub && <div className="text-xs text-gray-400 mt-1">{sub}</div>}
      {trend !== undefined && (
        <div
          className={`text-xs font-medium mt-1 ${
            trend > 0 ? 'text-red-500' : trend < 0 ? 'text-green-500' : 'text-gray-400'
          }`}
        >
          {trend > 0 ? '▲' : trend < 0 ? '▼' : '—'}{' '}
          {Math.abs(trend).toFixed(1)}%
        </div>
      )}
    </div>
  )
}

function ActualHoursTable() {
  const { roles, getMonths, actualHours, setActualHours } = useStore()
  const months = getMonths()
  const [editCell, setEditCell] = useState(null)

  if (!roles.length || !months.length) return null

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-xs">
        <thead>
          <tr className="border-b border-gray-100">
            <th className="text-left py-2 pr-4 font-medium text-gray-400 min-w-32">Rolle</th>
            {months.map((m) => (
              <th key={m} className={`text-center py-2 px-2 font-medium min-w-16 ${
                m === today ? 'text-indigo-600' : 'text-gray-400'
              }`}>
                {monthLabel(m)}
                {m === today && (
                  <div className="w-1.5 h-1.5 bg-indigo-600 rounded-full mx-auto mt-0.5" />
                )}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {roles.map((role) => (
            <tr key={role.id} className="border-b border-gray-50 hover:bg-gray-50/50">
              <td className="py-2 pr-4">
                <div className="flex items-center gap-2">
                  <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ background: role.color }} />
                  <span className="font-medium text-gray-700">{role.name}</span>
                </div>
              </td>
              {months.map((m) => {
                const val = actualHours[role.id]?.[m] ?? ''
                const isEdit = editCell === `${role.id}-${m}`
                const isFuture = isAfter(parseISO(m + '-01'), new Date())
                return (
                  <td key={m} className="py-1 px-1 text-center">
                    {isFuture ? (
                      <span className="text-gray-300">—</span>
                    ) : isEdit ? (
                      <input
                        type="number"
                        autoFocus
                        className="w-14 border border-indigo-300 rounded px-1 py-0.5 text-center text-xs focus:outline-none focus:ring-1 focus:ring-indigo-400"
                        value={val}
                        placeholder="0"
                        onChange={(e) => setActualHours(role.id, m, e.target.value)}
                        onBlur={() => setEditCell(null)}
                        onKeyDown={(e) => e.key === 'Enter' && setEditCell(null)}
                      />
                    ) : (
                      <button
                        onClick={() => setEditCell(`${role.id}-${m}`)}
                        className={`w-14 rounded px-1 py-0.5 text-center transition-colors cursor-pointer ${
                          val !== '' && val !== 0
                            ? 'text-gray-800 font-medium bg-gray-100 hover:bg-indigo-50'
                            : 'text-gray-300 hover:bg-gray-100 hover:text-gray-500'
                        }`}
                      >
                        {val !== '' ? `${val}h` : '—'}
                      </button>
                    )}
                  </td>
                )
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default function Controlling({ onBack }) {
  const {
    roles,
    getMonths,
    monthlyBudgets,
    actualHours,
    getTotalActualCost,
    getTotalPlannedCost,
    project,
  } = useStore()

  const months = getMonths()
  const currency = project.currency

  // ─── Aggregate data ────────────────────────────────────────────
  const totalBudget = project.totalBudget

  const chartData = months.reduce((acc, m) => {
    const budget = monthlyBudgets[m] || 0
    const planned = getTotalPlannedCost(m)
    const actual = getTotalActualCost(m)
    const isFuture = isAfter(parseISO(m + '-01'), new Date())
    const prev = acc[acc.length - 1]

    acc.push({
      month: monthLabel(m),
      Budget: budget,
      Geplant: Math.round(planned),
      Effektiv: isFuture ? null : Math.round(actual),
      cumBudget: (prev?.cumBudget ?? 0) + budget,
      cumActual: isFuture ? null : (prev?.cumActual ?? 0) + actual,
    })
    return acc
  }, [])

  const totalActualToDate = months
    .filter((m) => !isAfter(parseISO(m + '-01'), new Date()))
    .reduce((s, m) => s + getTotalActualCost(m), 0)

  const totalBudgetToDate = months
    .filter((m) => !isAfter(parseISO(m + '-01'), new Date()))
    .reduce((s, m) => s + (monthlyBudgets[m] || 0), 0)

  const budgetConsumedPct = totalBudget > 0 ? (totalActualToDate / totalBudget) * 100 : 0
  const remaining = totalBudget - totalActualToDate

  const pastMonths = months.filter((m) => !isAfter(parseISO(m + '-01'), new Date()))
  const avgMonthlyBurn = pastMonths.length > 0 ? totalActualToDate / pastMonths.length : 0
  const futureMonths = months.filter((m) => isAfter(parseISO(m + '-01'), new Date()))
  const forecastTotal = totalActualToDate + avgMonthlyBurn * futureMonths.length

  // Per-role breakdown for pie chart
  const roleBreakdown = roles.map((r) => {
    const totalHours = months
      .filter((m) => !isAfter(parseISO(m + '-01'), new Date()))
      .reduce((s, m) => s + (actualHours[r.id]?.[m] ?? 0), 0)
    const cost = totalHours * r.hourlyRate
    return { name: r.name, value: Math.round(cost), hours: Math.round(totalHours), color: r.color }
  }).filter((r) => r.value > 0)

  const exportCSV = () => {
    const header = ['Monat', 'Budget', 'Geplant', 'Effektiv', 'Abweichung']
    const rows = months.map((m) => {
      const budget = monthlyBudgets[m] || 0
      const planned = Math.round(getTotalPlannedCost(m))
      const actual = isAfter(parseISO(m + '-01'), new Date()) ? '' : Math.round(getTotalActualCost(m))
      const diff = actual !== '' ? actual - budget : ''
      return [fullMonthLabel(m), budget, planned, actual, diff]
    })
    const csv = [header, ...rows].map((r) => r.join(';')).join('\n')
    const blob = new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    const safeName = (project.name || 'projekt').replace(/[^\p{L}\p{N}\s_-]/gu, '').trim() || 'projekt'
    a.download = `budget-report-${safeName}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      {/* KPI Row */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <KPICard
          label="Gesamtbudget"
          value={fmt(totalBudget, currency)}
          sub={`${months.length} Monate`}
          color="indigo"
        />
        <KPICard
          label="Verbraucht bis heute"
          value={fmt(totalActualToDate, currency)}
          sub={`${budgetConsumedPct.toFixed(1)}% des Gesamtbudgets`}
          color={budgetConsumedPct > 90 ? 'red' : budgetConsumedPct > 70 ? 'amber' : 'green'}
        />
        <KPICard
          label="Restbudget"
          value={fmt(remaining, currency)}
          sub={remaining < 0 ? 'Budget überschritten!' : 'noch verfügbar'}
          color={remaining < 0 ? 'red' : remaining < totalBudget * 0.1 ? 'amber' : 'green'}
        />
        <KPICard
          label="Prognose Endkosten"
          value={fmt(forecastTotal, currency)}
          sub={`Ø ${fmt(avgMonthlyBurn, currency)}/Monat`}
          color={forecastTotal > totalBudget ? 'red' : forecastTotal > totalBudget * 0.9 ? 'amber' : 'green'}
          trend={totalBudget > 0 ? ((forecastTotal - totalBudget) / totalBudget) * 100 : undefined}
        />
      </div>

      {/* Budget progress */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">Budgetfortschritt</h2>
          <div className="text-sm font-semibold text-gray-600">
            {budgetConsumedPct.toFixed(1)}% verbraucht
          </div>
        </div>
        <div className="relative h-6 bg-gray-100 rounded-full overflow-hidden">
          <div
            className={`absolute left-0 top-0 h-full rounded-full transition-all ${
              budgetConsumedPct > 100 ? 'bg-red-500' : budgetConsumedPct > 80 ? 'bg-amber-500' : 'bg-green-500'
            }`}
            style={{ width: `${Math.min(100, budgetConsumedPct)}%` }}
          />
          {/* Forecast overlay */}
          {forecastTotal > totalActualToDate && totalBudget > 0 && (
            <div
              className="absolute top-0 h-full bg-indigo-200 opacity-50"
              style={{
                left: `${Math.min(100, budgetConsumedPct)}%`,
                width: `${Math.min(100 - budgetConsumedPct, ((forecastTotal - totalActualToDate) / totalBudget) * 100)}%`,
              }}
            />
          )}
        </div>
        <div className="flex justify-between text-xs text-gray-400 mt-1">
          <span>0</span>
          <span className="text-indigo-500">◆ Prognose: {pct(forecastTotal, totalBudget)}</span>
          <span>{fmt(totalBudget, currency)}</span>
        </div>
      </div>

      {/* Monthly chart */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-1">Budget vs. Effektiv</h2>
        <p className="text-xs text-gray-400 mb-4">Monatlicher Vergleich: Budgetiert, Geplant (Kapazität) und Effektiv</p>
        <ResponsiveContainer width="100%" height={300}>
          <ComposedChart data={chartData} barSize={18} barGap={2}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} tickFormatter={(v) => `${(v / 1000).toFixed(0)}k`} />
            <Tooltip content={<BudgetTooltip currency={currency} />} />
            <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: '11px', paddingTop: '12px' }} />
            <Bar dataKey="Budget" fill="#e0e7ff" radius={[4, 4, 0, 0]} />
            <Bar dataKey="Geplant" fill="#a5b4fc" radius={[4, 4, 0, 0]} />
            <Bar dataKey="Effektiv" fill="#6366f1" radius={[4, 4, 0, 0]}>
              {chartData.map((entry, i) => {
                const over = entry.Effektiv > entry.Budget
                return <Cell key={i} fill={over ? '#ef4444' : '#6366f1'} />
              })}
            </Bar>
          </ComposedChart>
        </ResponsiveContainer>
      </div>

      {/* Cumulative burn chart */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-1">Kumulativer Verlauf</h2>
        <p className="text-xs text-gray-400 mb-4">Gesamtkostenentwicklung über Zeit (Soll vs. Ist)</p>
        <ResponsiveContainer width="100%" height={250}>
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="gradBudget" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#e0e7ff" stopOpacity={0.8} />
                <stop offset="95%" stopColor="#e0e7ff" stopOpacity={0.1} />
              </linearGradient>
              <linearGradient id="gradActual" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#6366f1" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#6366f1" stopOpacity={0.0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
            <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fontSize: 11, fill: '#9ca3af' }} axisLine={false} tickLine={false} tickFormatter={(v) => `${(v / 1000).toFixed(0)}k`} />
            <Tooltip content={<BudgetTooltip currency={currency} />} />
            <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: '11px', paddingTop: '12px' }} />
            <Area
              type="monotone"
              dataKey="cumBudget"
              name="Kum. Budget"
              stroke="#a5b4fc"
              fill="url(#gradBudget)"
              strokeWidth={2}
              dot={false}
            />
            <Area
              type="monotone"
              dataKey="cumActual"
              name="Kum. Effektiv"
              stroke="#6366f1"
              fill="url(#gradActual)"
              strokeWidth={2}
              dot={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Actual hours input + pie */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Effektive Stunden</h2>
              <p className="text-xs text-gray-400 mt-0.5">Klicke auf eine Zelle zum Bearbeiten</p>
            </div>
          </div>
          <ActualHoursTable />
        </div>

        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <h2 className="text-lg font-semibold text-gray-900 mb-1">Kostenverteilung</h2>
          <p className="text-xs text-gray-400 mb-4">Nach Rolle (effektiv)</p>
          {roleBreakdown.length > 0 ? (
            <>
              <ResponsiveContainer width="100%" height={180}>
                <PieChart>
                  <Pie
                    data={roleBreakdown}
                    cx="50%"
                    cy="50%"
                    innerRadius={50}
                    outerRadius={80}
                    dataKey="value"
                    paddingAngle={2}
                  >
                    {roleBreakdown.map((entry) => (
                      <Cell key={entry.name} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    formatter={(v, n, p) => [
                      `${fmt(v, currency)} (${p.payload.hours}h)`,
                      n,
                    ]}
                    contentStyle={{ fontSize: '11px', borderRadius: '8px' }}
                  />
                </PieChart>
              </ResponsiveContainer>
              <div className="mt-3 space-y-2">
                {roleBreakdown.map((r) => (
                  <div key={r.name} className="flex items-center justify-between text-xs">
                    <div className="flex items-center gap-2">
                      <div className="w-2.5 h-2.5 rounded-full" style={{ background: r.color }} />
                      <span className="text-gray-600">{r.name}</span>
                    </div>
                    <span className="font-medium text-gray-800">
                      {fmt(r.value, currency)}
                    </span>
                  </div>
                ))}
              </div>
            </>
          ) : (
            <div className="text-center py-8 text-gray-300 text-sm">
              Noch keine Stunden erfasst
            </div>
          )}
        </div>
      </div>

      {/* Monthly detail table */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">Monatsübersicht</h2>
          <button
            onClick={exportCSV}
            className="bg-gray-100 text-gray-700 px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-gray-200 transition-colors"
          >
            ↓ CSV Export
          </button>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-gray-100">
                <th className="text-left py-2 pr-4 font-medium text-gray-400">Monat</th>
                <th className="text-right py-2 px-3 font-medium text-gray-400">Budget</th>
                <th className="text-right py-2 px-3 font-medium text-gray-400">Geplant</th>
                <th className="text-right py-2 px-3 font-medium text-gray-400">Effektiv</th>
                <th className="text-right py-2 px-3 font-medium text-gray-400">Abweichung</th>
                <th className="text-right py-2 pl-3 font-medium text-gray-400">Status</th>
              </tr>
            </thead>
            <tbody>
              {months.map((m) => {
                const budget = monthlyBudgets[m] || 0
                const planned = Math.round(getTotalPlannedCost(m))
                const isFuture = isAfter(parseISO(m + '-01'), new Date())
                const actual = isFuture ? null : Math.round(getTotalActualCost(m))
                const diff = actual !== null ? actual - budget : null
                const isToday = m === today

                return (
                  <tr
                    key={m}
                    className={`border-b border-gray-50 hover:bg-gray-50/50 ${
                      isToday ? 'bg-indigo-50/30' : ''
                    }`}
                  >
                    <td className="py-2 pr-4 font-medium text-gray-700">
                      {fullMonthLabel(m)}
                      {isToday && (
                        <span className="ml-2 inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-indigo-100 text-indigo-700">
                          aktuell
                        </span>
                      )}
                    </td>
                    <td className="py-2 px-3 text-right text-gray-600">
                      {fmt(budget, currency)}
                    </td>
                    <td className="py-2 px-3 text-right text-gray-500">
                      {fmt(planned, currency)}
                    </td>
                    <td className="py-2 px-3 text-right font-medium text-gray-800">
                      {actual !== null ? fmt(actual, currency) : '—'}
                    </td>
                    <td
                      className={`py-2 px-3 text-right font-medium ${
                        diff === null
                          ? 'text-gray-300'
                          : diff > 0
                          ? 'text-red-600'
                          : diff < 0
                          ? 'text-green-600'
                          : 'text-gray-400'
                      }`}
                    >
                      {diff !== null
                        ? `${diff > 0 ? '+' : ''}${fmt(diff, currency)}`
                        : '—'}
                    </td>
                    <td className="py-2 pl-3 text-right">
                      {isFuture ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-500">
                          geplant
                        </span>
                      ) : actual === 0 ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-400">
                          offen
                        </span>
                      ) : diff !== null && diff > 0 ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                          über Budget
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-700">
                          im Budget
                        </span>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
            <tfoot>
              <tr className="border-t-2 border-gray-200">
                <td className="py-3 pr-4 font-semibold text-gray-900">Total</td>
                <td className="py-3 px-3 text-right font-semibold text-gray-900">
                  {fmt(totalBudget, currency)}
                </td>
                <td className="py-3 px-3 text-right font-semibold text-gray-600">
                  {fmt(
                    months.reduce((s, m) => s + getTotalPlannedCost(m), 0),
                    currency
                  )}
                </td>
                <td className="py-3 px-3 text-right font-semibold text-gray-900">
                  {fmt(totalActualToDate, currency)}
                </td>
                <td
                  className={`py-3 px-3 text-right font-semibold ${
                    totalActualToDate - totalBudgetToDate > 0 ? 'text-red-600' : 'text-green-600'
                  }`}
                >
                  {fmt(totalActualToDate - totalBudgetToDate, currency)}
                </td>
                <td />
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <div className="flex justify-between">
        <button
          onClick={onBack}
          className="px-4 py-2 rounded-lg text-sm font-medium text-gray-600 border border-gray-200 hover:bg-gray-50 transition-colors"
        >
          ← Zurück
        </button>
        <button
          onClick={exportCSV}
          className="bg-indigo-600 text-white px-6 py-2.5 rounded-lg font-medium text-sm hover:bg-indigo-700 transition-colors"
        >
          ↓ Report exportieren (CSV)
        </button>
      </div>
    </div>
  )
}
