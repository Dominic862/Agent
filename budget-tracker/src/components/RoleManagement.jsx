import { useState } from 'react'
import { format, parseISO, getDaysInMonth } from 'date-fns'
import { de } from 'date-fns/locale'
import { useStore } from '../store'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'

const COLORS = [
  '#6366f1', '#f59e0b', '#10b981', '#ef4444', '#8b5cf6',
  '#ec4899', '#14b8a6', '#f97316', '#3b82f6', '#84cc16',
]

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

function AddRoleModal({ onClose, onAdd, nextColor }) {
  const [form, setForm] = useState({ name: '', hourlyRate: '', color: nextColor })
  return (
    <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-xl p-6 w-full max-w-md">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Neue Rolle</h3>
        <div className="space-y-3">
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Rollenbezeichnung</label>
            <input
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="z.B. Projektleiter, Entwickler, Designer..."
              value={form.name}
              onChange={(e) => setForm({ ...form, name: e.target.value })}
              autoFocus
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Stundensatz (CHF/h)</label>
            <input
              type="number"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="0"
              value={form.hourlyRate}
              onChange={(e) => setForm({ ...form, hourlyRate: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">Farbe</label>
            <div className="flex gap-2 flex-wrap">
              {COLORS.map((c) => (
                <button
                  key={c}
                  onClick={() => setForm({ ...form, color: c })}
                  className={`w-7 h-7 rounded-full border-2 transition-all cursor-pointer ${
                    form.color === c ? 'border-gray-900 scale-110' : 'border-transparent'
                  }`}
                  style={{ background: c }}
                />
              ))}
            </div>
          </div>
        </div>
        <div className="flex justify-end gap-2 mt-5">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-lg text-sm font-medium text-gray-600 hover:bg-gray-100 transition-colors"
          >
            Abbrechen
          </button>
          <button
            onClick={() => form.name && onAdd(form)}
            disabled={!form.name}
            className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors disabled:opacity-40"
          >
            Hinzufügen
          </button>
        </div>
      </div>
    </div>
  )
}

function AvailabilityGrid({ role }) {
  const { getMonths, setRoleAvailability, getMonthlyCapacity } = useStore()
  const months = getMonths()
  const [editing, setEditing] = useState(null)

  return (
    <div className="mt-3">
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2">
        {months.map((m) => {
          const avail = role.availability[m] || {}
          const hoursPerWeek = avail.hoursPerWeek ?? 40
          const vacationDays = avail.vacationDays ?? 0
          const capacity = getMonthlyCapacity(role.id, m)
          const isEditing = editing === m

          const workDays = Math.round((getDaysInMonth(parseISO(m + '-01')) / 7) * 5)
          const utilizationPct = workDays > 0 ? (1 - vacationDays / workDays) * 100 : 100
          const bottleneck = hoursPerWeek < 20 || vacationDays >= workDays * 0.5

          return (
            <div
              key={m}
              className={`rounded-xl border p-3 cursor-pointer transition-all ${
                isEditing
                  ? 'border-indigo-400 bg-indigo-50'
                  : bottleneck
                  ? 'border-red-200 bg-red-50 hover:border-red-300'
                  : 'border-gray-100 bg-gray-50 hover:border-gray-200'
              }`}
              onClick={() => setEditing(isEditing ? null : m)}
            >
              <div className="text-xs font-medium text-gray-500 mb-2">{monthLabel(m)}</div>
              {isEditing ? (
                <div className="space-y-2" onClick={(e) => e.stopPropagation()}>
                  <div>
                    <div className="text-xs text-gray-400 mb-0.5">h/Woche</div>
                    <input
                      type="number"
                      className="w-full border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-indigo-400"
                      value={hoursPerWeek}
                      min="0"
                      max="60"
                      onChange={(e) =>
                        setRoleAvailability(role.id, m, { hoursPerWeek: Number(e.target.value) })
                      }
                    />
                  </div>
                  <div>
                    <div className="text-xs text-gray-400 mb-0.5">Ferientage</div>
                    <input
                      type="number"
                      className="w-full border border-gray-200 rounded px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-indigo-400"
                      value={vacationDays}
                      min="0"
                      max="31"
                      onChange={(e) =>
                        setRoleAvailability(role.id, m, { vacationDays: Number(e.target.value) })
                      }
                    />
                  </div>
                  <button
                    onClick={() => setEditing(null)}
                    className="w-full text-xs text-indigo-600 font-medium mt-1"
                  >
                    ✓ Fertig
                  </button>
                </div>
              ) : (
                <div className="space-y-1">
                  <div className="flex items-center justify-between">
                    <span className="text-xs text-gray-500">{hoursPerWeek}h/W</span>
                    {vacationDays > 0 && (
                      <span className="text-xs text-amber-600">🏖 {vacationDays}d</span>
                    )}
                  </div>
                  <div className="text-sm font-semibold text-gray-800">
                    {Math.round(capacity)}h
                  </div>
                  <div className="h-1.5 bg-gray-200 rounded-full overflow-hidden">
                    <div
                      className={`h-full rounded-full ${bottleneck ? 'bg-red-400' : 'bg-green-400'}`}
                      style={{ width: `${Math.min(100, utilizationPct)}%` }}
                    />
                  </div>
                  {bottleneck && (
                    <div className="text-xs text-red-500 font-medium">⚠ Engpass</div>
                  )}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

const CustomTooltip = ({ active, payload, label }) => {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-white rounded-xl shadow-lg border border-gray-100 p-3 text-xs">
      <div className="font-semibold text-gray-700 mb-2">{label}</div>
      {payload.map((p) => (
        <div key={p.name} className="flex items-center gap-2 mb-0.5">
          <div className="w-2 h-2 rounded-full" style={{ background: p.fill }} />
          <span className="text-gray-500">{p.name}:</span>
          <span className="font-medium text-gray-800">
            {Math.round(p.value)}h
          </span>
        </div>
      ))}
      <div className="mt-1 pt-1 border-t border-gray-100 font-semibold text-gray-700">
        Total: {Math.round(payload.reduce((s, p) => s + p.value, 0))}h
      </div>
    </div>
  )
}

export default function RoleManagement({ onBack, onNext }) {
  const { roles, addRole, updateRole, removeRole, getMonths, project } = useStore()
  const [showModal, setShowModal] = useState(false)
  const [expandedRole, setExpandedRole] = useState(null)

  const months = getMonths()
  const nextColor = COLORS[roles.length % COLORS.length]

  const { getMonthlyCapacity } = useStore()

  const chartData = months.map((m) => {
    const entry = { month: monthLabel(m) }
    roles.forEach((r) => {
      entry[r.name] = Math.round(getMonthlyCapacity(r.id, m))
    })
    return entry
  })

  const bottleneckMonths = months.filter((m) => {
    return roles.some((r) => {
      const avail = r.availability[m] || {}
      const hw = avail.hoursPerWeek ?? 40
      const vd = avail.vacationDays ?? 0
      const wd = Math.round((getDaysInMonth(parseISO(m + '-01')) / 7) * 5)
      return hw < 20 || vd >= wd * 0.5
    })
  })

  return (
    <div className="space-y-6">
      {/* Roles list */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">Rollen & Team</h2>
            <p className="text-xs text-gray-400 mt-0.5">
              {roles.length} Rolle{roles.length !== 1 ? 'n' : ''} definiert
            </p>
          </div>
          <button
            onClick={() => setShowModal(true)}
            className="bg-indigo-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-indigo-700 transition-colors"
          >
            + Rolle hinzufügen
          </button>
        </div>

        {roles.length === 0 ? (
          <div className="text-center py-12 text-gray-400">
            <div className="text-4xl mb-3">👥</div>
            <p className="text-sm">Noch keine Rollen definiert. Füge die erste Rolle hinzu.</p>
          </div>
        ) : (
          <div className="space-y-3">
            {roles.map((role) => {
              const totalCap = months.reduce(
                (s, m) => s + getMonthlyCapacity(role.id, m),
                0
              )
              const totalCost = totalCap * role.hourlyRate
              const hasBottleneck = months.some((m) => {
                const avail = role.availability[m] || {}
                const hw = avail.hoursPerWeek ?? 40
                const vd = avail.vacationDays ?? 0
                const wd = Math.round((getDaysInMonth(parseISO(m + '-01')) / 7) * 5)
                return hw < 20 || vd >= wd * 0.5
              })

              return (
                <div
                  key={role.id}
                  className="border border-gray-100 rounded-xl overflow-hidden"
                >
                  <div className="flex items-center justify-between p-4">
                    <div className="flex items-center gap-3">
                      <div
                        className="w-4 h-4 rounded-full flex-shrink-0"
                        style={{ background: role.color }}
                      />
                      <div>
                        <div className="flex items-center gap-2">
                          <input
                            className="font-semibold text-gray-900 text-sm bg-transparent border-none outline-none focus:bg-gray-50 rounded px-1 -mx-1"
                            value={role.name}
                            onChange={(e) => updateRole(role.id, { name: e.target.value })}
                          />
                          {hasBottleneck && (
                            <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                              ⚠ Engpass
                            </span>
                          )}
                        </div>
                        <div className="flex items-center gap-3 mt-0.5 text-xs text-gray-400">
                          <span>
                            {new Intl.NumberFormat('de-CH').format(role.hourlyRate)} {project.currency}/h
                          </span>
                          <span>·</span>
                          <span>{Math.round(totalCap)}h total</span>
                          <span>·</span>
                          <span>
                            {new Intl.NumberFormat('de-CH', { maximumFractionDigits: 0 }).format(totalCost)} {project.currency}
                          </span>
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <div className="flex items-center gap-2 mr-2">
                        <label className="text-xs text-gray-400">CHF/h</label>
                        <input
                          type="number"
                          className="w-20 border border-gray-200 rounded-lg px-2 py-1 text-xs focus:outline-none focus:ring-1 focus:ring-indigo-400 text-right"
                          value={role.hourlyRate}
                          onChange={(e) => updateRole(role.id, { hourlyRate: Number(e.target.value) })}
                        />
                      </div>
                      <button
                        onClick={() => setExpandedRole(expandedRole === role.id ? null : role.id)}
                        className="text-xs text-indigo-600 font-medium px-3 py-1.5 rounded-lg hover:bg-indigo-50 transition-colors"
                      >
                        {expandedRole === role.id ? '▲ Einklappen' : '▼ Verfügbarkeit'}
                      </button>
                      <button
                        onClick={() => removeRole(role.id)}
                        className="text-xs text-red-500 px-2 py-1.5 rounded-lg hover:bg-red-50 transition-colors"
                      >
                        ✕
                      </button>
                    </div>
                  </div>

                  {expandedRole === role.id && (
                    <div className="border-t border-gray-50 px-4 pb-4 pt-3 bg-gray-50/50">
                      <p className="text-xs text-gray-400 mb-2">
                        Klicke auf einen Monat, um Stunden/Woche und Ferientage anzupassen.
                      </p>
                      <AvailabilityGrid role={role} />
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Capacity Chart */}
      {roles.length > 0 && months.length > 0 && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">Kapazitätsübersicht</h2>
              <p className="text-xs text-gray-400 mt-0.5">Verfügbare Stunden pro Monat und Rolle</p>
            </div>
            {bottleneckMonths.length > 0 && (
              <div className="inline-flex items-center px-3 py-1.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
                ⚠ {bottleneckMonths.length} Engpass-Monat{bottleneckMonths.length !== 1 ? 'e' : ''}
              </div>
            )}
          </div>

          <ResponsiveContainer width="100%" height={280}>
            <BarChart data={chartData} barSize={16} barGap={2}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
              <XAxis
                dataKey="month"
                tick={{ fontSize: 11, fill: '#9ca3af' }}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                tick={{ fontSize: 11, fill: '#9ca3af' }}
                axisLine={false}
                tickLine={false}
                tickFormatter={(v) => `${v}h`}
              />
              <Tooltip content={<CustomTooltip />} />
              <Legend
                iconType="circle"
                iconSize={8}
                wrapperStyle={{ fontSize: '11px', paddingTop: '12px' }}
              />
              {roles.map((r) => (
                <Bar key={r.id} dataKey={r.name} stackId="a" fill={r.color} radius={[0, 0, 0, 0]} />
              ))}
            </BarChart>
          </ResponsiveContainer>

          {bottleneckMonths.length > 0 && (
            <div className="mt-4 p-3 bg-red-50 rounded-xl">
              <div className="text-xs font-semibold text-red-700 mb-1">Engpässe erkannt:</div>
              <div className="text-xs text-red-600">
                {bottleneckMonths.map(fullMonthLabel).join(', ')}
              </div>
            </div>
          )}
        </div>
      )}

      <div className="flex justify-between">
        <button
          onClick={onBack}
          className="px-4 py-2 rounded-lg text-sm font-medium text-gray-600 border border-gray-200 hover:bg-gray-50 transition-colors"
        >
          ← Zurück
        </button>
        <button
          onClick={onNext}
          disabled={roles.length === 0}
          className="bg-indigo-600 text-white px-6 py-2.5 rounded-lg font-medium text-sm hover:bg-indigo-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Weiter zu Controlling →
        </button>
      </div>

      {showModal && (
        <AddRoleModal
          nextColor={nextColor}
          onClose={() => setShowModal(false)}
          onAdd={(role) => {
            addRole(role)
            setShowModal(false)
            setExpandedRole(null)
          }}
        />
      )}
    </div>
  )
}
