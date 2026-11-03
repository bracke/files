with Files.Environment;
with Ada.Text_IO;

package body Files.Diagnostics is

   procedure Note
     (Occurrence : Ada.Exceptions.Exception_Occurrence;
      Where      : String) is
   begin
      if Files.Environment.Is_Set ("FILES_DIAGNOSTICS") then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            --  A developer trace, not prose: a fixed marker for grep.
            "files-diagnostics" & ':' & ' ' & Where & ':' & ' '
            & Ada.Exceptions.Exception_Information (Occurrence));
      end if;
   exception
      --  A trace must never turn a tolerated failure into a new one.
      when others =>
         null;
   end Note;

   --  Callbacks from the window system may run on another task.
   protected Loop_Counter is
      procedure Add;
      function Value return Natural;
   private
      Count : Natural := 0;
   end Loop_Counter;

   protected body Loop_Counter is
      procedure Add is
      begin
         if Count < Natural'Last then
            Count := Count + 1;
         end if;
      end Add;

      function Value return Natural is (Count);
   end Loop_Counter;

   procedure Note_Event_Loop (Occurrence : Ada.Exceptions.Exception_Occurrence) is
   begin
      Loop_Counter.Add;
      Note (Occurrence, "Files.Application.Windows");
   end Note_Event_Loop;

   function Event_Loop_Failures return Natural is (Loop_Counter.Value);

   procedure Trace (Where : String; Message : String) is
   begin
      if Files.Environment.Is_Set ("FILES_DIAGNOSTICS") then
         Ada.Text_IO.Put_Line
           --  Its own marker: a trace is no failure, and CI fails on the
           --  exception marker (files-diagnostics:) alone.
           (Ada.Text_IO.Standard_Error, "files-trace" & ':' & ' ' & Where & ':' & ' ' & Message);
      end if;
   exception
      when others =>
         null;
   end Trace;

end Files.Diagnostics;
