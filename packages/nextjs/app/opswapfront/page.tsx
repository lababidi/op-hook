"use client";

import { useEffect, useState } from "react";

export default function OpSwapFront() {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    console.log("OpSwap page is loading!");
    // Check system preference on mount
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    setIsDark(prefersDark);
  }, []);

  const toggleTheme = () => {
    setIsDark(!isDark);
  };

  return (
    <div
      className={`min-h-screen transition-colors duration-300 font-light ${
        isDark ? "bg-black text-white" : "bg-white text-black"
      }`}
    >
      <div className="container mx-auto px-4 py-8">
        {/* Header */}
        <header className="flex justify-between items-center mb-12">
          <div className="flex items-center space-x-4">
            {/* Placeholder Logo */}
            <div
              className={`w-12 h-12 rounded-lg flex items-center justify-center ${isDark ? "bg-white" : "bg-black"}`}
            >
              <span className={`font-medium text-xl ${isDark ? "text-black" : "text-white"}`}>OS</span>
            </div>
            <h1 className="text-3xl font-semibold font-geist">OpSwap</h1>
          </div>

          {/* Theme Toggle */}
          <button
            onClick={toggleTheme}
            className={`relative p-3 rounded-full transition-all duration-300 transform hover:scale-105 ${
              isDark
                ? "bg-white hover:bg-gray-100 shadow-lg shadow-white/20"
                : "bg-black hover:bg-gray-800 shadow-lg shadow-black/20"
            }`}
            aria-label="Toggle theme"
          >
            <span className="text-lg">{isDark ? "☀️" : "🌙"}</span>
          </button>
        </header>

        {/* Main Content */}
        <main className="max-w-4xl mx-auto">
          {/* Hero Section */}
          <section className="text-center mb-16">
            <h2 className={`text-5xl font-light mb-6 tracking-wide ${isDark ? "text-white" : "text-black"}`}>
              Decentralized Options Trading
            </h2>
            <p className={`text-xl mb-8 font-light ${isDark ? "text-gray-300" : "text-gray-600"}`}>
              Trade options on Ethereum with advanced DeFi protocols
            </p>
            <div className="flex justify-center space-x-4">
              <button
                className={`px-6 py-3 rounded-lg font-light transition-colors ${
                  isDark ? "bg-white hover:bg-gray-100 text-black" : "bg-black hover:bg-gray-800 text-white"
                }`}
              >
                Start Trading
              </button>
              <button
                className={`px-6 py-3 rounded-lg font-light border transition-colors ${
                  isDark
                    ? "border-gray-600 hover:bg-gray-900 text-white"
                    : "border-gray-300 hover:bg-gray-50 text-black"
                }`}
              >
                Learn More
              </button>
            </div>
          </section>

          {/* Features Grid */}
          <section className="grid md:grid-cols-3 gap-8 mb-16">
            <div
              className={`p-6 rounded-xl border ${
                isDark ? "bg-gray-900 border-gray-800" : "bg-gray-50 border-gray-200"
              }`}
            >
              <h3 className="text-2xl font-light mb-4">🔄 Liquidity</h3>
              <p className={`font-light ${isDark ? "text-gray-300" : "text-gray-600"}`}>
                Deep liquidity pools for seamless options trading
              </p>
            </div>

            <div
              className={`p-6 rounded-xl border ${
                isDark ? "bg-gray-900 border-gray-800" : "bg-gray-50 border-gray-200"
              }`}
            >
              <h3 className="text-2xl font-light mb-4">⚡ Speed</h3>
              <p className={`font-light ${isDark ? "text-gray-300" : "text-gray-600"}`}>
                Instant settlement on Ethereum L2 networks
              </p>
            </div>

            <div
              className={`p-6 rounded-xl border ${
                isDark ? "bg-gray-900 border-gray-800" : "bg-gray-50 border-gray-200"
              }`}
            >
              <h3 className="text-2xl font-light mb-4">🔒 Security</h3>
              <p className={`font-light ${isDark ? "text-gray-300" : "text-gray-600"}`}>
                Audited smart contracts with advanced security
              </p>
            </div>
          </section>

          {/* Stats Section */}
          <section
            className={`p-8 rounded-xl mb-16 border ${
              isDark ? "bg-gray-900 border-gray-800" : "bg-gray-50 border-gray-200"
            }`}
          >
            <h3 className="text-2xl font-light text-center mb-8">Platform Stats</h3>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 text-center">
              <div>
                <div className={`text-3xl font-light ${isDark ? "text-white" : "text-black"}`}>$50M+</div>
                <div className={`text-sm font-light ${isDark ? "text-gray-400" : "text-gray-500"}`}>Total Volume</div>
              </div>
              <div>
                <div className={`text-3xl font-light ${isDark ? "text-white" : "text-black"}`}>10K+</div>
                <div className={`text-sm font-light ${isDark ? "text-gray-400" : "text-gray-500"}`}>Active Traders</div>
              </div>
              <div>
                <div className={`text-3xl font-light ${isDark ? "text-white" : "text-black"}`}>99.9%</div>
                <div className={`text-sm font-light ${isDark ? "text-gray-400" : "text-gray-500"}`}>Uptime</div>
              </div>
              <div>
                <div className={`text-3xl font-light ${isDark ? "text-white" : "text-black"}`}>24/7</div>
                <div className={`text-sm font-light ${isDark ? "text-gray-400" : "text-gray-500"}`}>Trading</div>
              </div>
            </div>
          </section>
        </main>

        {/* Footer */}
        <footer className={`text-center py-8 border-t font-light ${isDark ? "border-gray-800" : "border-gray-200"}`}>
          <p className={isDark ? "text-gray-400" : "text-gray-500"}>© 2024 OpSwap. Built with ❤️ on Ethereum</p>
        </footer>
      </div>
    </div>
  );
}
