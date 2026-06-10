import { useState } from 'react'
import BudgetSetup from './components/BudgetSetup'
import RoleManagement from './components/RoleManagement'
import Controlling from './components/Controlling'
import { useStore } from './store'

const STEPS = [
  { id: 0, label: 'Budget', icon: '💰', desc: 'Projekt & Monatsbudgets' },
  { id: 1, label: 'Rollen', icon: '👥', desc: 'Team & Verfügbarkeit' },
  { id: 2, label: 'Controlling', icon: '📊', desc: 'Ist vs. Soll & Reporting' },
]

export default function App() {
  const [activeStep, setActiveStep] = useState(0)
  const project = useStore((s) => s.project)

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center text-white font-bold text-sm">
              B
            </div>
            <div>
              <div className="font-semibold text-gray-900 text-sm">
                {project.name || 'Budget Tracker'}
              </div>
              {project.name && (
                <div className="text-xs text-gray-400">{project.currency}</div>
              )}
            </div>
          </div>

          <nav className="flex items-center gap-1">
            {STEPS.map((step) => (
              <button
                key={step.id}
                onClick={() => setActiveStep(step.id)}
                className={`flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all cursor-pointer ${
                  activeStep === step.id
                    ? 'bg-indigo-600 text-white shadow-sm'
                    : 'text-gray-500 hover:bg-gray-100 hover:text-gray-700'
                }`}
              >
                <span>{step.icon}</span>
                <span className="hidden sm:inline">{step.label}</span>
              </button>
            ))}
          </nav>

          <div className="w-20" />
        </div>
      </header>

      <div className="bg-white border-b border-gray-100">
        <div className="max-w-7xl mx-auto px-4 py-2 flex items-center gap-4">
          {STEPS.map((step, i) => (
            <div key={step.id} className="flex items-center gap-2">
              <div
                className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                  activeStep === step.id
                    ? 'bg-indigo-600 text-white'
                    : activeStep > step.id
                    ? 'bg-green-500 text-white'
                    : 'bg-gray-200 text-gray-500'
                }`}
              >
                {activeStep > step.id ? '✓' : step.id + 1}
              </div>
              <span
                className={`text-xs font-medium ${
                  activeStep === step.id ? 'text-indigo-600' : 'text-gray-400'
                }`}
              >
                {step.desc}
              </span>
              {i < STEPS.length - 1 && (
                <div className="w-8 h-px bg-gray-200 ml-2" />
              )}
            </div>
          ))}
        </div>
      </div>

      <main className="max-w-7xl mx-auto px-4 py-6">
        {activeStep === 0 && <BudgetSetup onNext={() => setActiveStep(1)} />}
        {activeStep === 1 && (
          <RoleManagement
            onBack={() => setActiveStep(0)}
            onNext={() => setActiveStep(2)}
          />
        )}
        {activeStep === 2 && <Controlling onBack={() => setActiveStep(1)} />}
      </main>
    </div>
  )
}
