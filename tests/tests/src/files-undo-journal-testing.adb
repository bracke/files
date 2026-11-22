package body Files.Undo.Journal.Testing is

   procedure Refuse_Reads (Count : Natural) is
   begin
      Refused_Reads := Count;
   end Refuse_Reads;

   function Refusals_Left return Natural is (Refused_Reads);

   procedure Save_Stacks
     (Directory : String;
      Undo, Redo : Files.Undo.History.Undo_Entry_Vectors.Vector;
      Mode : Save_Mode := Best_Effort;
      State : Files.Undo.History.History_Journal_State := (others => <>)) renames Files.Undo.Journal.Save_Stacks;

end Files.Undo.Journal.Testing;
