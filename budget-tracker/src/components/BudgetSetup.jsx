import { format, parseISO } from 'date-fns'
import { de } from 'date-fns/locale'
import { useStore } from '../store'

const CURRENCIES = ['CHF', 'EUR', 'USD', 'GBP']

const fmt = (val) =>
  new Intl.NumberFormat('de-CH', { maximumFractionDigits: 0 }).format(val || 0)

export default function BudgetSetup({ onNext }) {
  const { project, setProject, monthlyBudgets, setMonthlyBudget, distributeEvenly, getMonths } =
    useStore()

  const months = getMonths()
  const totalMonthly = months.reduce((s, m) => s + (monthlyBudgets[m] || 0), 0)

  const monthLabel = (m) => {
    try {
      return format(parseISO(m + '-01'), 'MMM yyyy', { locale: de })
    } catch {
      return m
    }
  }

  return (
    <div className="space-y-6">
      {/* Project Info Card */}
      <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
        <h2 className="text-lg font-semibold text-gray-900 mb-4">
          Projektdetails
        </h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="lg:col-span-2">
            <label className="block text-xs font-medium text-gray-500 mb-1">
              Projektname
            </label>
            <input
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="z.B. Digitalisierungsprojekt 2024"
              value={project.name}
              onChange={(e) => setProject({ name: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">
              Währung
            </label>
            <select
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white"
              value={project.currency}
              onChange={(e) => setProject({ currency: e.target.value })}
            >
              {CURRENCIES.map((c) => (
                <option key={c}>{c}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">
              Gesamtbudget ({project.currency})
            </label>
            <input
              type="number"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="0"
              value={project.totalBudget || ''}
              onChange={(e) => setProject({ totalBudget: Number(e.target.value) })}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">
              Startdatum
            </label>
            <input
              type="date"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              value={project.startDate}
              onChange={(e) => setProject({ startDate: e.target.value })}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 mb-1">
              Enddatum
            </label>
            <input
              type="date"
              className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              value={project.endDate}
              onChange={(e) => setProject({ endDate: e.target.value })}
            />
          </div>
        </div>
      </div>

      {/* Monthly Budget Card */}
      {months.length > 0 && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-6">
          <div className="flex items-center justify-between mb-4">
            <div>
              <h2 className="text-lg font-semibold text-gray-900">
                Monatsbudgets
              </h2>
              <p className="text-xs text-gray-400 mt-0.5">
                {months.length} Monate · Gesamtbudget: {fmt(project.totalBudget)}{' '}
                {project.currency}
              </p>
            </div>
            <div className="flex items-center gap-2">
              <button
                onClick={distributeEvenly}
                className="bg-indigo-50 text-indigo-700 px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-indigo-100 transition-colors"
              >
                Gleichmässig verteilen
              </button>
            </div>
          </div>

          {/* Budget summary bar */}
          <div className="mb-6 p-4 rounded-xl bg-gray-50 flex items-center justify-between">
            <div className="text-sm text-gray-600">
              Verteilt:{' '}
              <span className="font-semibold text-gray-900">
                {fmt(totalMonthly)} {project.currency}
              </span>
            </div>
            <div
              className={`text-sm font-medium ${
                totalMonthly > project.totalBudget
                  ? 'text-red-600'
                  : totalMonthly === project.totalBudget
                  ? 'text-green-600'
                  : 'text-amber-600'
              }`}
            >
              {totalMonthly > project.totalBudget
                ? `Überschreitung: ${fmt(totalMonthly - project.totalBudget)}`
                : totalMonthly === project.totalBudget
                ? '✓ Budget vollständig verteilt'
                : `Noch zu verteilen: ${fmt(project.totalBudget - totalMonthly)}`}
            </div>
          </div>

          {/* Progress bar */}
          {project.totalBudget > 0 && (
            <div className="mb-6">
              <div className="h-2 bg-gray-100 rounded-full overflow-hidden">
                <div
                  className={`h-full rounded-full transition-all ${
                    totalMonthly > project.totalBudget ? 'bg-red-500' : 'bg-indigo-500'
                  }`}
                  style={{
                    width: `${Math.min(100, (totalMonthly / project.totalBudget) * 100)}%`,
                  }}
                />
              </div>
            </div>
          )}

          {/* Monthly grid */}
          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
            {months.map((m) => {
              const val = monthlyBudgets[m] || 0
              const pct = project.totalBudget > 0 ? (val / project.totalBudget) * 100 : 0
              return (
                <div key={m} className="group relative">
                  <label className="block text-xs font-medium text-gray-500 mb-1">
                    {monthLabel(m)}
                  </label>
                  <div className="relative">
                    <input
                      type="number"
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 pr-8"
                      value={val || ''}
                      placeholder="0"
                      onChange={(e) => setMonthlyBudget(m, e.target.value)}
                    />
                    {pct > 0 && (
                      <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-gray-400">
                        {pct.toFixed(0)}%
                      </span>
                    )}
                  </div>
                  <div className="mt-1 h-1 bg-gray-100 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-indigo-400 rounded-full"
                      style={{ width: `${Math.min(100, pct)}%` }}
                    />
                  </div>
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* Empty state */}
      {months.length === 0 && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-100 p-12 text-center text-gray-400">
          <div className="text-4xl mb-3">📅</div>
          <p className="text-sm">Bitte Start- und Enddatum eingeben, um die Monatsbudgets zu definieren.</p>
        </div>
      )}

      {/* Next button */}
      <div className="flex justify-end">
        <button
          onClick={onNext}
          disabled={!project.name || months.length === 0}
          className="bg-indigo-600 text-white px-6 py-2.5 rounded-lg font-medium text-sm hover:bg-indigo-700 transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
        >
          Weiter zu Rollen →
        </button>
      </div>
    </div>
  )
}
