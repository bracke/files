with Files.Diagnostics;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

package body Files.Background_Slots is
   use Ada.Strings.Unbounded;

   type Request_State is record
      Owner     : Requester := 0;
      Path      : Unbounded_String;
      Arguments : Parameters;
      Pending   : Boolean := False;
      Done      : Boolean := False;
      Value     : Result;
      --  When the request was made: the worker serves the oldest first.
      Stamp     : Long_Long_Integer := 0;
   end record;

   --  One slot per window that has asked: it grows with the windows, so no
   --  window's request is ever evicted to make room for another's.
   package Request_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Request_State);

   protected Slots is
      procedure Put (Owner : Requester; Path : String; Arguments : Parameters);
      procedure Next
        (Found     : out Boolean;
         Owner     : out Requester;
         Path      : out Unbounded_String;
         Arguments : out Parameters);
      procedure Deliver
        (Owner     : Requester;
         Path      : Unbounded_String;
         Arguments : Parameters;
         Value     : Result);
      procedure Collect
        (Owner : Requester;
         Path  : String;
         Value : out Result;
         Ready : out Boolean;
         Asked : out Boolean);
      procedure Collect_Exact
        (Owner     : Requester;
         Path      : String;
         Arguments : Parameters;
         Value     : out Result;
         Ready     : out Boolean;
         Asked     : out Boolean);
      procedure Forget (Owner : Requester);
      function Waiting return Boolean;
   private
      States : Request_Vectors.Vector;
      Clock  : Long_Long_Integer := 0;
   end Slots;

   protected body Slots is
      function Slot_Of (Owner : Requester) return Natural is
      begin
         for Index in States.First_Index .. States.Last_Index loop
            if States (Index).Owner = Owner then
               return Index;
            end if;
         end loop;
         return 0;
      end Slot_Of;

      procedure Put (Owner : Requester; Path : String; Arguments : Parameters) is
         Index : constant Natural := Slot_Of (Owner);
         State : constant Request_State :=
           (Owner => Owner, Path => To_Unbounded_String (Path), Arguments => Arguments,
            Pending => True, Done => False, Value => Failed, Stamp => Clock);
      begin
         Clock := Clock + 1;
         if Index = 0 then
            States.Append (State);
         else
            States.Replace_Element (Index, State);
         end if;
      end Put;

      procedure Next
        (Found     : out Boolean;
         Owner     : out Requester;
         Path      : out Unbounded_String;
         Arguments : out Parameters)
      is
         Oldest : Natural := 0;
      begin
         Found := False;
         Owner := 0;
         Path := Null_Unbounded_String;
         --  The request waiting longest, so a window that keeps asking never
         --  holds another's back.
         for Index in States.First_Index .. States.Last_Index loop
            if States (Index).Pending
              and then (Oldest = 0 or else States (Index).Stamp < States (Oldest).Stamp)
            then
               Oldest := Index;
            end if;
         end loop;
         if Oldest /= 0 then
            States (Oldest).Pending := False;
            Found := True;
            Owner := States (Oldest).Owner;
            Path := States (Oldest).Path;
            Arguments := States (Oldest).Arguments;
         end if;
      end Next;

      procedure Deliver
        (Owner     : Requester;
         Path      : Unbounded_String;
         Arguments : Parameters;
         Value     : Result)
      is
         Index : constant Natural := Slot_Of (Owner);
      begin
         --  Kept only while the owner still asks for this file with these
         --  parameters: a read of an older revision, finished after the
         --  owner asked again, is dropped.
         if Index /= 0
           and then States (Index).Path = Path
           and then States (Index).Arguments = Arguments
           and then not States (Index).Pending
         then
            States (Index).Done := True;
            States (Index).Value := Value;
         end if;
      end Deliver;

      --  Hand out the result in the slot at Index when Asked and it is in.
      procedure Hand_Out
        (Index : Natural;
         Asked : Boolean;
         Value : out Result;
         Ready : out Boolean) is
      begin
         Ready := Asked and then States (Index).Done;
         if Ready then
            Value := States (Index).Value;
            --  A success is handed out once, and its slot goes. A failure
            --  stays in the slot, so the next poll learns it again instead
            --  of asking for the same file over and over.
            if Handed_Once (Value) then
               States.Delete (Index);
            end if;
         else
            Value := Failed;
         end if;
      end Hand_Out;

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
         Hand_Out (Index, Asked, Value, Ready);
      end Collect;

      procedure Collect_Exact
        (Owner     : Requester;
         Path      : String;
         Arguments : Parameters;
         Value     : out Result;
         Ready     : out Boolean;
         Asked     : out Boolean)
      is
         Index : constant Natural := Slot_Of (Owner);
      begin
         Asked := Index /= 0
           and then To_String (States (Index).Path) = Path
           and then States (Index).Arguments = Arguments;
         Hand_Out (Index, Asked, Value, Ready);
      end Collect_Exact;

      procedure Forget (Owner : Requester) is
         Index : constant Natural := Slot_Of (Owner);
      begin
         if Index /= 0 then
            States.Delete (Index);
         end if;
      end Forget;

      function Waiting return Boolean is
        (for some State of States => State.Pending);
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
               Slots.Deliver (Owner, Path, Arguments, Value);
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

   --  A wake-up can be missed between the worker's last look and its return
   --  to waiting: a poll that finds nothing ready wakes it again, which costs
   --  nothing.
   procedure Nudge (Ready : Boolean) is
   begin
      if not Ready and then Slots.Waiting then
         Kick;
      end if;
   end Nudge;

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
      Nudge (Ready);
   end Take;

   procedure Take
     (Owner     : Requester;
      Path      : String;
      Arguments : Parameters;
      Value     : out Result;
      Ready     : out Boolean;
      Asked     : out Boolean) is
   begin
      Slots.Collect_Exact (Owner, Path, Arguments, Value, Ready, Asked);
      Nudge (Ready);
   end Take;

   procedure Release (Owner : Requester) is
   begin
      Slots.Forget (Owner);
   end Release;

end Files.Background_Slots;
