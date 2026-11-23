with Ada.Containers.Vectors;
separate (Files.Settings.Path_References)
procedure Follow_Path_Moves
  (Settings : in out Settings_Model;
   Moves    : Files.Types.Path_Move_Vectors.Vector;
   Changed  : out Boolean)
is
   use all type Files.Types.Path_Move_Kind;

   package Step_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Positive);
   package Step_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Step_Vectors.Vector,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Step_Vectors."=");
   package Arrival_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type => String, Element_Type => Positive, Hash => Ada.Strings.Hash, Equivalent_Keys => "=");

   --  The moves, each by the key (Key) of the path it moves, in the order
   --  they were made: one look-up per head of a stored path finds what
   --  moved it, rather than a pass over the stored paths per move.
   Steps : Step_Maps.Map;

   --  Where a stored path ends up: its path, or gone; the last move that
   --  took it (0: none).
   type Followed is record
      Path      : Unbounded_String;
      Gone      : Boolean := False;
      Last_Step : Natural := 0;
   end record;

   --  The last move each label's key was arrived at by (labels only).
   Arrivals : Arrival_Maps.Map;

   --  The first move after After that takes Path: one whose path is Path
   --  itself or a folder Path lies in. Path's heads are matched whole by
   --  key, as Same matches, so two spellings of one folder match even where
   --  folding changes their length. Head_Last: where the matched head ends.
   procedure Next_Step (Path : String; After : Natural; Step : out Natural; Head_Last : out Natural) is
      procedure Consider (Last : Natural) is
         Found : constant Step_Maps.Cursor := Steps.Find (Key (Path (Path'First .. Last)));
      begin
         if Step_Maps.Has_Element (Found) then
            for Candidate of Step_Maps.Element (Found) loop
               if Candidate > After then
                  if Step = 0 or else Candidate < Step then
                     Step := Candidate;
                     Head_Last := Last;
                  end if;
                  exit;
               end if;
            end loop;
         end if;
      end Consider;
   begin
      Step := 0;
      Head_Last := 0;
      --  A head ends before each separator and, for a root such as "/" or
      --  "C:\" (or a folder given with its separator), at it: the heads
      --  Hostkit.Fs.Is_Same_Or_Inside counts a path inside.
      for Index in Path'Range loop
         if Hostkit.Fs.Is_Separator (Path (Index)) then
            if Index > Path'First then
               Consider (Index - 1);
            end if;
            Consider (Index);
         end if;
      end loop;
      Consider (Path'Last);
   end Next_Step;

   --  Follow Path through the moves in order; with Note, record each place
   --  it arrives at in Arrivals.
   procedure Walk (Path : String; Note : Boolean; Result : out Followed) is
      Step      : Natural;
      Head_Last : Natural;
   begin
      Result := (Path => To_Unbounded_String (Path), others => <>);
      loop
         declare
            Now : constant String := To_String (Result.Path);
         begin
            Next_Step (Now, Result.Last_Step, Step, Head_Last);
            exit when Step = 0;
            Result.Last_Step := Step;
            if Moves (Step).Kind = Removed then
               Result.Gone := True;
               exit;
            end if;
            Result.Path := Moves (Step).To & Now (Head_Last + 1 .. Now'Last);
         end;
         if Note then
            declare
               Arrived : constant String := Key (To_String (Result.Path));
            begin
               --  Steps only grow along the walks, but walks of other labels
               --  may have recorded a later one already.
               if not Arrivals.Contains (Arrived) or else Arrivals (Arrived) < Step then
                  Arrivals.Include (Arrived, Step);
               end if;
            end;
         end if;
      end loop;
   end Walk;

   --  Favorites or recent paths: each one moved is rewritten, each one
   --  removed goes, and where a rewritten one lands on a path listed more
   --  than once, the first listed stays and the others go: a path is
   --  listed once.
   procedure Follow (Paths : in out String_Vectors.Vector) is
      type Walk_Array is array (Positive range <>) of Followed;
      Walks     : Walk_Array (1 .. Natural (Paths.Length));
      Any       : Boolean := False;
      Rewritten : Path_Sets.Set;
      Seen      : Path_Sets.Set;
      Kept      : String_Vectors.Vector;
   begin
      for Index in Walks'Range loop
         Walk (To_String (Paths (Index)), Note => False, Result => Walks (Index));
         if Walks (Index).Last_Step /= 0 then
            Any := True;
            if not Walks (Index).Gone then
               Rewritten.Include (Key (To_String (Walks (Index).Path)));
            end if;
         end if;
      end loop;
      if not Any then
         return;
      end if;
      Changed := True;
      for Index in Walks'Range loop
         if not Walks (Index).Gone then
            declare
               Keyed : constant String := Key (To_String (Walks (Index).Path));
            begin
               if not Rewritten.Contains (Keyed) or else not Seen.Contains (Keyed) then
                  Kept.Append (Walks (Index).Path);
                  Seen.Include (Keyed);
               end if;
            end;
         end if;
      end loop;
      Paths.Move (Kept);
   end Follow;

   procedure Follow_Labels is
      type Walk_Array is array (Positive range <>) of Followed;
      Labels : Path_Label_Vectors.Vector renames Settings.Paths.Labels;
      Walks  : Walk_Array (1 .. Natural (Labels.Length));
      Any    : Boolean := False;
      Kept   : Path_Label_Vectors.Vector;
   begin
      for Index in Walks'Range loop
         Walk (To_String (Labels (Index).Path), Note => True, Result => Walks (Index));
         Any := Any or else Walks (Index).Last_Step /= 0;
      end loop;
      if not Any then
         return;
      end if;
      for Index in Walks'Range loop
         declare
            Path    : constant String := To_String (Walks (Index).Path);
            Arrived : constant Arrival_Maps.Cursor :=
              (if Walks (Index).Gone then Arrival_Maps.No_Element else Arrivals.Find (Key (Path)));
         begin
            --  A label at a place another labelled entry was moved onto
            --  after it got there belonged to what was there before: the
            --  moved entry's label is the one that holds.
            if Walks (Index).Gone
              or else (Arrival_Maps.Has_Element (Arrived)
                       and then Arrival_Maps.Element (Arrived) > Walks (Index).Last_Step)
            then
               Changed := True;
            else
               if Path /= To_String (Labels (Index).Path) then
                  Changed := True;
               end if;
               Kept.Append (Path_Label'(Path => Walks (Index).Path, Label => Labels (Index).Label));
            end if;
         end;
      end loop;
      Labels.Move (Kept);
   end Follow_Labels;

begin
   Restamp (Settings.Paths);
   Changed := False;
   for Step in Moves.First_Index .. Moves.Last_Index loop
      declare
         Move : Files.Types.Path_Move renames Moves (Step);
         From : constant String := To_String (Move.From);
      begin
         if From /= ""
           and then (Move.Kind = Removed or else (Move.To /= "" and then Move.To /= Move.From))
         then
            declare
               Keyed : constant String := Key (From);
            begin
               if not Steps.Contains (Keyed) then
                  Steps.Insert (Keyed, Step_Vectors.Empty_Vector);
               end if;
               Steps (Keyed).Append (Step);
            end;
         end if;
      end;
   end loop;
   if Steps.Is_Empty then
      return;
   end if;
   Follow (Settings.Paths.Favorites);
   Follow (Settings.Paths.Recent);
   Follow_Labels;
end Follow_Path_Moves;
