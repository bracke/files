separate (Files.Application.Windows)
   procedure Reveal_Pending_Selection (Runtime : in out Runtime_Window) is
   begin
      if Files.Model.Reveal_Is_Pending (Runtime.Model) then
         Reveal_Selection (Runtime);
      end if;
   end Reveal_Pending_Selection;
