;nyquist plug-in
;version 4
;type process
;name "Murky Surround"
;action "Adding murky textures..."
;author "RedMoth & Gemini"

;; --- UI CONTROLS ---
;control rev-time "Reverb tail length (sec)" float "" 0.5 0.1 10.0
;control delay-ms "Right channel delay (ms)" float "" 20.0 0.0 30.0
;control rev-gain "Murkiness volume (%)" float "" 50.0 0.0 200.0
;control out-gain "Output gain (dB)" float "" -6.0 -24.0 6.0
;control inv-toggle "Right channel inversion" choice "Off,On (Wide)" 1

(if (arrayp *track*)
    (let* (
           (delay-sec (/ delay-ms 1000.0))

           (l-orig (aref *track* 0))
           (r-orig (aref *track* 1))

           ;; 1. Base equalization (+4dB at 6kHz and 8kHz)
           (l-main (eq-band (eq-band l-orig 6000 4 1.0) 8000 4 1.0))
           (r-main (eq-band (eq-band r-orig 6000 4 1.0) 8000 4 1.0))

           ;; 2. Isolate 100% WET reverb
           (l-wet (diff (jcrev l-orig rev-time 1.0) l-orig))
           (r-wet (diff (jcrev r-orig rev-time 1.0) r-orig))

           ;; 3. Create the "murk" (Low-pass filter at 800Hz + Gain adjustment)
           (l-murky (mult (/ rev-gain 100.0) (lp l-wet 800)))
           (r-murky (mult (/ rev-gain 100.0) (lp r-wet 800)))

           ;; 4. Delay the right channel BEFORE inversion
           ;; Using s-rest to physically pad with silence for Audacity stability
           (r-del (abs-env (sim (s-rest delay-sec) (at delay-sec (cue r-murky)))))

           ;; 5. Invert the right channel using the -0.999 DSP trick
           (r-final-murky (if (= inv-toggle 1) (mult -0.999 r-del) r-del))

           ;; 6. Final Mix (Base + Murk)
           (final-l (sim l-main l-murky))
           (final-r (sim r-main r-final-murky))
          )
      ;; Apply final output gain
      (mult (db-to-linear out-gain) (vector final-l final-r)))

    "Error: This effect requires a stereo track!")
