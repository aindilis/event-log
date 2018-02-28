(global-set-key "\C-cvlr" 'event-log-push-recently-interacted-with-files-onto-stack)

(defun event-log-push-recently-interacted-with-files-onto-stack ()
 ""
 (interactive)
 (see
  (uea-query-agent-raw nil "ELog"
   (freekbs2-util-data-dumper
    (list
     (cons "Command" "list-recent")
     (cons "Condensed" 1)
     (cons "_DoNotLog" 1))))))

