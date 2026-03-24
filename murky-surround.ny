;nyquist plug-in
;version 4
;type process
;name "Murky Surround"
;author "RedMoth and Gemini"
;release "1.0.1"
;copyright "Released under terms of the MIT License"
;codetype lisp
;preview linear
;debugbutton disabled

;; --- UI CONTROLS ---
;control rev-time "Reverb tail length" float "sec" 0.5 0.1 10.0
;control delay-ms "Right channel delay" float "ms" 20.0 0.0 30.0
;control rev-gain "Murkiness volume" float "%" 50.0 0.0 200.0
;control out-gain "Output gain" float "dB" -6.0 -24.0 6.0
;control inv-toggle "Right channel inversion" choice "Off,On (Wide)" 1

(if (arrayp *track*)
    (let* ((delay-sec (/ delay-ms 1000.0))
           (len-sec (get-duration 1)) 

           ;; 1. Векторная базовая эквализация
           (base-eq (eq-band (eq-band *track* 6000 4 1.0) 8000 4 1.0))

           ;; 2. Изоляция 100% WET реверберации
           (wet-rev (diff (multichan-expand #'jcrev *track* rev-time 1.0) *track*))

           ;; 3. Векторный "Murk"
           (murk-stereo (mult (/ rev-gain 100.0) (lp wet-rev 800)))

           ;; Разделяем каналы для асимметричной обработки задержкой
           (l-murky (aref murk-stereo 0))
           (r-murky (aref murk-stereo 1))

           ;; 4. Задержка правого канала
           (r-del (abs-env (sim (s-rest delay-sec) (at delay-sec (cue r-murky)))))

           ;; 5. Инверсия фазы правого канала (-0.999 DSP trick)
           (r-final-murky (if (= inv-toggle 1) (mult -0.999 r-del) r-del))

           ;; 6. Финальное микширование по каналам с учетом громкости
           (final-l (mult (db-to-linear out-gain) (sim (aref base-eq 0) l-murky)))
           (final-r (mult (db-to-linear out-gain) (sim (aref base-eq 1) r-final-murky))))
           
      ;; Жестко отрезаем хвосты ПОКАНАЛЬНО, чтобы Nyquist не спотыкался об массивы
      (vector (extract-abs 0 len-sec (cue final-l))
              (extract-abs 0 len-sec (cue final-r))))
      
    "Error: This effect requires a stereo track!")
