https://sourceforge.net/p/morse-rss-news/code/HEAD/tree/trunk/iambickeyer/IambicKeyer.cs

//tabs=4
//-----------------------------------------------------------------------------
// TITLE:		IambicKeyer.cs
//
// FACILITY:	Iambic Morse Code Keyer
//
// ABSTRACT:	Implements an Iambic Morse code keyer. Key events (up/down)
//				are sent via a method call, and the dits and dahs are passed 
//				back to a delegate which is passed as a parameter to the ctor.
//				Both Iambic mode "A" and mode "B" are supported, with move "B"
//				being the default.
//
// IMPORTANT:	The Sender delegate must be synchronous, that is, it must not
//				return until the symbol is actually sent (tone played, etc.).
//
// ENVIRONMENT:	Microsoft.NET 2.0/3.5
//				Developed under Visual Studio.NET 2008
//				Also may be built under MonoDevelop 2.2.1/Mono 2.4+
//
// AUTHOR:		Bob Denny, <rdenny@dc3.com>
//
// Edit Log:
//
// When			Who		What
//----------	---		-------------------------------------------------------
// ??-Apr-10	rbd		Initial development within the Iambic Keyer program.
// 07-May-10	rbd		Refactored this into a separate assembly for multi-use.
//
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text;
using System.Threading;

namespace com.dc3.morse
{
	class IambicKeyer : IDisposable
	{
		
		private bool _ditDown;
		private bool _ditWas;
		private bool _dahDown;
		private bool _dahWas;
		private object _stateLock;
		private SendSymbol _sender;
		private AutoResetEvent _trigger;
		private Thread _keyerThread;

		public bool ModeB { get; set; }

		public enum KeyEventType
		{
			DitPress,
			DitRelease,
			DahPress,
			DahRelease
		}

		public enum MorseSymbol
		{
			Dit,
			Dah
		}

		public delegate void SendSymbol(MorseSymbol S);

		public IambicKeyer(SendSymbol Sender)
		{
			ModeB = true;
			_ditDown = _ditWas = _dahDown = _dahWas = false;
			_trigger = new AutoResetEvent(false);
			_stateLock = new object();
			_sender = Sender;
			_keyerThread = new Thread(new ThreadStart(KeyerThread));
			//_keyerThread.Priority = ThreadPriority.AboveNormal;
			_keyerThread.Name = "Iambic keyer";
			_keyerThread.Start();
		}

		public void  Dispose()
		{
 			_keyerThread.Interrupt();
			_keyerThread.Join(1000);
		}

		public void KeyEvent(KeyEventType Evt)
		{
			//Debug.Print("-->" + Evt.ToString());
			lock (_stateLock)
			{
				switch (Evt)
				{
					case KeyEventType.DitPress: _ditDown = _ditWas = true; break;
					case KeyEventType.DitRelease: _ditDown = false; break;
					case KeyEventType.DahPress: _dahDown = _dahWas = true; break;
					case KeyEventType.DahRelease: _dahDown = false; break;
				}
			}
			_trigger.Set();
		}

		private void KeyerThread()
		{
			bool alt = false;
			bool lastDit = true;

			while (true)
			{
				try { _trigger.WaitOne(); }
				catch (ThreadInterruptedException) { break; }					// Program exiting

				//Debug.Print("(outer-loop)");
				if (!_ditDown && !_ditWas && !_dahDown && !_dahWas)
				{
					//Debug.Print("False False False False");
					//Debug.Print("alt=" + alt.ToString() + " lastSent=" + (lastDit ? "Dit" : "Dah"));
					if (alt && ModeB)
					{
						//Debug.Print(lastDit ? " *dah!" : " *dit!");
						_sender(lastDit ? MorseSymbol.Dah : MorseSymbol.Dit);
					}
					//Debug.Print("");
					alt = false;
				}
				while (_ditDown || _ditWas || _dahDown || _dahWas)
				{
					//Debug.Print("1 " +_ditDown.ToString() + " " + _ditWas.ToString() + " " + _dahDown.ToString() + " " + _dahWas.ToString());
					alt = false; // (_ditDown && _dahDown);
					if (_ditDown || _ditWas)
					{
						//Debug.Print("  dit!");
						_sender(MorseSymbol.Dit);
						lock (_stateLock) { _ditWas = false; }
						lastDit = true;
					}
					//Debug.Print("2 " + _ditDown.ToString() + " " + _ditWas.ToString() + " " + _dahDown.ToString() + " " + _dahWas.ToString());
					alt |= (_ditDown && _dahDown);
					if (_dahDown || _dahWas)
					{
						//Debug.Print("  dah!");
						_sender(MorseSymbol.Dah);
						lock (_stateLock) { _dahWas = false; }
						lastDit = false;
					}
					//Debug.Print("3 " + _ditDown.ToString() + " " + _ditWas.ToString() + " " + _dahDown.ToString() + " " + _dahWas.ToString());
					alt |= (_ditDown && _dahDown);
				}

			}
		}
	}
}
