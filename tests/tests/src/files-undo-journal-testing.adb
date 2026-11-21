package body Files.Undo.Journal.Testing is

   procedure Refuse_Reads (Count : Natural) is
   begin
      Refused_Reads := Count;
   end Refuse_Reads;

   function Refusals_Left return Natural is (Refused_Reads);

end Files.Undo.Journal.Testing;
