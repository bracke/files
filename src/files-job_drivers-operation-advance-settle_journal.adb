separate (Files.Job_Drivers.Operation.Advance)
function Settle_Journal (Missing : out Boolean) return Boolean is
begin
   Missing := False;
   case Merge_Journal (Transport, Model) is
      when Files.Undo.Journal.Read_Whole =>
         null;
      when Files.Undo.Journal.Unreadable =>
         if Defer_Merge (Model, Transport) then
            return False;
         end if;
         History_Lost := True;
      when Files.Undo.Journal.No_Journal =>
         Missing := True;
   end case;
   Merged := True;
   return True;
end Settle_Journal;
