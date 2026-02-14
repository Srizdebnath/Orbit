'use client'

import { useState, useEffect } from 'react'
import { useAccount, useConnect, useDisconnect, useSendTransaction } from 'wagmi'
import { ArrowRight, Wallet, Loader2, Send, Terminal } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

// Define the shape of the backend response
type SwapRoute = {
  token_in_address: string
  token_out_address: string
  amount_in_wei: number
  min_amount_out_wei: number
  router_address: string
  calldata: `0x${string}` // Viem expects hex strings to start with 0x
  estimated_gas: number
}

type Message = {
  role: 'user' | 'agent'
  content: string
  type?: 'text' | 'transaction'
  data?: SwapRoute
}

export default function Home() {
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()
  const { disconnect } = useDisconnect()
  const { sendTransaction, isPending, isSuccess, error: txError } = useSendTransaction()
  
  const [input, setInput] = useState('')
  const [isLoading, setIsLoading] = useState(false)
  const [messages, setMessages] = useState<Message[]>([
    { role: 'agent', content: 'gm. I am Orbit. Tell me what you want to swap (e.g., "Swap 10 USDC to ETH on Optimism").' }
  ])

  // Scroll to bottom of chat
  useEffect(() => {
    const chatBox = document.getElementById('chat-box')
    if (chatBox) chatBox.scrollTop = chatBox.scrollHeight
  }, [messages])

  const handleSend = async () => {
    if (!input.trim()) return

    // 1. Add User Message
    const userMsg = input
    setMessages(prev => [...prev, { role: 'user', content: userMsg }])
    setInput('')
    setIsLoading(true)

    try {
      // 2. Call Python Backend
      const response = await fetch('http://127.0.0.1:8000/solve_intent', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          raw_text: userMsg,
          user_address: address || "0x0000000000000000000000000000000000000000"
        })
      })

      if (!response.ok) throw new Error('Failed to parse intent')
      
      const routeData: SwapRoute = await response.json()

      // 3. Add Agent Response with Transaction Data
      setMessages(prev => [...prev, {
        role: 'agent',
        content: `I found a route! Swap ${routeData.amount_in_wei} Wei for at least ${routeData.min_amount_out_wei} Wei. Ready to sign?`,
        type: 'transaction',
        data: routeData
      }])

    } catch (error) {
      setMessages(prev => [...prev, { role: 'agent', content: "Sorry, I couldn't calculate a route for that. Try again." }])
      console.error(error)
    } finally {
      setIsLoading(false)
    }
  }

  const handleExecuteSwap = (route: SwapRoute) => {
    if (!isConnected) {
      alert("Please connect your wallet first")
      return
    }

    // 4. Send Transaction to Blockchain
    console.log("Sending TX to:", route.router_address)
    console.log("Calldata:", route.calldata)

    sendTransaction({
      to: route.router_address as `0x${string}`, 
      data: route.calldata,
      value: BigInt(0), // If swapping ETH, we'd need to pass value here. For ERC20, value is 0.
    })
  }

  return (
    <main className="flex min-h-screen flex-col bg-zinc-950 text-white font-mono">
      {/* Header */}
      <header className="flex justify-between items-center p-6 border-b border-zinc-800">
        <div className="flex items-center gap-2">
          <div className="w-4 h-4 bg-blue-500 rounded-full animate-pulse" />
          <h1 className="text-xl font-bold tracking-tighter">ORBIT <span className="text-zinc-500">PROTOCOL</span></h1>
        </div>
        
        {isConnected ? (
          <button onClick={() => disconnect()} className="text-xs bg-zinc-900 border border-zinc-700 px-4 py-2 rounded hover:bg-zinc-800 transition">
            {address?.slice(0,6)}...{address?.slice(-4)}
          </button>
        ) : (
          <button onClick={() => connect({ connector: connectors[0] })} className="flex items-center gap-2 text-xs bg-blue-600 px-4 py-2 rounded hover:bg-blue-700 transition">
            <Wallet size={14} /> Connect Wallet
          </button>
        )}
      </header>

      {/* Chat Area */}
      <div id="chat-box" className="flex-1 overflow-y-auto p-6 space-y-6 max-w-3xl mx-auto w-full">
        <AnimatePresence>
          {messages.map((m, i) => (
            <motion.div 
              key={i} 
              initial={{ opacity: 0, y: 10 }} 
              animate={{ opacity: 1, y: 0 }}
              className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div className={`max-w-[80%] p-4 rounded-lg border ${
                m.role === 'user' 
                  ? 'bg-blue-900/20 border-blue-800 text-blue-100' 
                  : 'bg-zinc-900 border-zinc-800 text-zinc-300'
              }`}>
                <p className="text-sm">{m.content}</p>
                
                {/* Transaction Card */}
                {m.type === 'transaction' && m.data && (
                  <div className="mt-4 p-4 bg-black/50 rounded border border-zinc-700">
                    <div className="flex justify-between text-xs text-zinc-500 mb-2">
                      <span>Gas Estimate</span>
                      <span>{m.data.estimated_gas}</span>
                    </div>
                    <div className="flex items-center justify-between bg-zinc-800 p-2 rounded mb-2">
                      <code className="text-xs text-green-400">{m.data.token_in_address.slice(0,6)}...</code>
                      <ArrowRight size={14} className="text-zinc-500"/>
                      <code className="text-xs text-blue-400">{m.data.token_out_address.slice(0,6)}...</code>
                    </div>
                    
                    {!isConnected ? (
                      <div className="text-xs text-red-400 mt-2">Connect wallet to execute</div>
                    ) : (
                      <button 
                        onClick={() => handleExecuteSwap(m.data!)}
                        disabled={isPending}
                        className="w-full mt-2 bg-green-600 hover:bg-green-700 text-white text-xs py-3 rounded flex items-center justify-center gap-2 transition"
                      >
                        {isPending ? <Loader2 className="animate-spin" size={14} /> : <Terminal size={14} />}
                        {isPending ? 'Signing...' : 'Sign Transaction'}
                      </button>
                    )}
                    
                    {isSuccess && <p className="text-xs text-green-500 mt-2 text-center">Transaction Sent!</p>}
                    {txError && <p className="text-xs text-red-500 mt-2 text-center">Error: {txError.message.slice(0, 50)}...</p>}
                  </div>
                )}
              </div>
            </motion.div>
          ))}
          {isLoading && (
            <div className="flex justify-start">
              <div className="bg-zinc-900 border border-zinc-800 p-4 rounded-lg">
                <Loader2 className="animate-spin text-zinc-500" size={16} />
              </div>
            </div>
          )}
        </AnimatePresence>
      </div>

      {/* Input Area */}
      <div className="p-6 border-t border-zinc-800 bg-zinc-950">
        <div className="max-w-3xl mx-auto relative">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Swap 100 USDC to ETH on Base..."
            className="w-full bg-zinc-900 border border-zinc-700 rounded-xl px-4 py-4 pr-12 text-sm focus:outline-none focus:ring-2 focus:ring-blue-900 transition"
          />
          <button 
            onClick={handleSend}
            className="absolute right-3 top-3 p-1 bg-blue-600 rounded-lg hover:bg-blue-700 transition"
          >
            <Send size={16} />
          </button>
        </div>
      </div>
    </main>
  )
}