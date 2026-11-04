with Files.Diagnostics;
with Ada.Strings.Unbounded;

package body Files.Background_Slots is
   use Ada.Strings.Unbounded;

   --  Windows asking at once: a few. The oldest slot goes when all are taken.
   Max_Requesters : constant := 8;

   type Request_State is record
      Used      : Boolean := False;
      Owner     : Requester := 0;
      Path      : Unbounded_String;
      Arguments : Parameters;
      Pending   : Boolean := False;
      Done      : Boolean := False;
      Value     : Result;
      Stamp     : Natural := 0;
   end record;

   type Request_Array is array (1 .. Max_Requesters) of Request_State;

   protected Slots is
      procedure Put (Owner : Requester; Path : String; Arguments : Parameters);
      procedure Next
        (Found     : out Boolean;
         Owner     : out Requester;
         Path      : out Unbounded_String;
         Arguments : out Parameters);
      procedure Deliver (Owner : Requester; Path : Unbounded_String; Value : Result);
      procedure Collect
        (Owner : Requester;
         Path  : String;
         Value : out Result;
         Ready : out Boolean;
         Asked : out Boolean);
      function Waiting return Boolean;
   private
      States : Request_Array;
      Clock  : Natural := 0;
   end Slots;

   protected body Slots is
      function Slot_Of (Owner : Requester) return Natural is
      begin
         for Index in States'Range loop
            if States (Index).Used and then States (Index).Owner = Owner then
               return Index;
            end if;
         end loop;
         return 0;
      end Slot_Of;

      procedure Put (Owner : Requester; Path : String; Arguments : Parameters) is
         Index : Natural := Slot_Of (Owner);
      begin
         if Index = 0 then
            --  A free slot, else the one asked of longest ago.
            for Candidate in States'Range loop
               if not States (Candidate).Used then
                  Index := Candidate;
                  exit;
               elsif Index = 0 or else States (Candidate).Stamp < States (Index).Stamp then
                  Index := Candidate;
               end if;
            end loop;
         end if;
         Clock := (if Clock = Natural'Last then 0 else Clock + 1);
         States (Index) :=
           (Used => True, Owner => Owner, Path => To_Unbounded_String (Path), Arguments => Arguments,
            Pending => True, Done => False, Value => Failed, Stamp => Clock);
      end Put;

      procedure Next
        (Found     : out Boolean;
         Owner     : out Requester;
         Path      : out Unbounded_String;
         Arguments : out Parameters) is
      begin
         Found := False;
         Owner := 0;
         Path := Null_Unbounded_String;
         for State of States loop
            if State.Used and then State.Pending then
               State.Pending := False;
               Found := True;
               Owner := State.Owner;
               Path := State.Path;
               Arguments := State.Arguments;
               return;
            end if;
         end loop;
      end Next;

      procedure Deliver (Owner : Requester; Path : Unbounded_String; Value : Result) is
         Index : constant Natural := Slot_Of (Owner);
      begin
         --  Kept only while the owner still asks for this file.
         if Index /= 0 and then States (Index).Path = Path and then not States (Index).Pending then
            States (Index).Done := True;
            States (Index).Value := Value;
         end if;
      end Deliver;

      procedure Collect
        (Owner : Requester;
         Path  : String;
         Value : out Result;
         Ready : out Boolean;
         Asked : out Boolean)
      is
         Index : constant Natural := Slot_Of (Owner);
      begin
         Asked := Index /= 0 and then To_String (States (Index).Path) = Path;
         Ready := Asked and then States (Index).Done;
         if Ready then
            Value := States (Index).Value;
            --  A success is handed out once. A failure stays in the slot, so
            --  the next poll learns it again instead of asking for the same
            --  file over and over.
            if Handed_Once (Value) then
               States (Index).Used := False;
               States (Index).Path := Null_Unbounded_String;
               States (Index).Done := False;
               States (Index).Value := Failed;
            end if;
         else
            Value := Failed;
         end if;
      end Collect;

      function Waiting return Boolean is
        (for some State of States => State.Used and then State.Pending);
   end Slots;

   task Worker is
      entry Wake;
   end Worker;

   task body Worker is
      Found     : Boolean;
      Owner     : Requester;
      Path      : Unbounded_String;
      Arguments : Parameters;
   begin
      loop
         select
            accept Wake;
         or
            terminate;
         end select;
         loop
            Slots.Next (Found, Owner, Path, Arguments);
            exit when not Found;
            declare
               Value : Result;
            begin
               begin
                  Value := Work (To_String (Path), Arguments);
               exception
                  when Swallowed : others =>
                     Files.Diagnostics.Note (Swallowed, "Files.Background_Slots");
                     Value := Failed;
               end;
               Slots.Deliver (Owner, Path, Value);
            end;
         end loop;
      end loop;
   end Worker;

   --  Wake the worker if it is waiting; when it is busy it takes the request
   --  after the current one.
   procedure Kick is
   begin
      select
         Worker.Wake;
      else
         null;
      end select;
   end Kick;

   procedure Request (Owner : Requester; Path : String; Arguments : Parameters) is
   begin
      Slots.Put (Owner, Path, Arguments);
      Kick;
   end Request;

   procedure Take
     (Owner : Requester;
      Path  : String;
      Value : out Result;
      Ready : out Boolean;
      Asked : out Boolean) is
   begin
      Slots.Collect (Owner, Path, Value, Ready, Asked);
      --  A wake-up can be missed between the worker's last look and its
      --  return to waiting: asking again costs nothing.
      if not Ready and then Slots.Waiting then
         Kick;
      end if;
   end Take;

end Files.Background_Slots;
