with Ada.Containers.Vectors;

with Files.Types;

--  Pure, side-effect-free paste/move conflict-resolution core.
--
--  This package models a paste (or cut-and-paste move) as a work-list of
--  destination items and, given a conflict policy plus any per-item overrides
--  and the set of destination paths that already exist, computes the concrete
--  actions to perform: write (create), write-over (replace), skip, or write to a
--  uniquified name (rename). It performs no filesystem access and no rendering;
--  existence is supplied as data (the Existing vector), which makes the whole
--  resolution deterministically unit-testable. Callers detect conflicts, drive
--  the interactive dialog, and execute the resolved actions elsewhere.
package Files.Paste is

   --  Batch-wide conflict policy. Policy_Ask leaves each conflict for the user
   --  to decide (its effective per-item decision stays Decision_Pending); the
   --  *_All policies apply one choice to every remaining conflict at once.
   type Conflict_Policy is
     (Policy_Ask,
      Policy_Replace_All,
      Policy_Skip_All,
      Policy_Rename_All);

   --  A per-item decision. Decision_Pending means "not yet decided"; the
   --  concrete choices mirror the dialog buttons.
   type Item_Decision is
     (Decision_Pending,
      Decision_Replace,
      Decision_Skip,
      Decision_Rename);

   package Item_Decision_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Item_Decision);

   --  One planned destination for a source path. Dest_Dir and Dest_Name give the
   --  desired (un-uniquified) destination; conflicts are detected against that
   --  joined path.
   type Work_Item is record
      Source_Path : Files.Types.UString;
      Dest_Dir    : Files.Types.UString;
      Dest_Name   : Files.Types.UString;
   end record;

   package Work_Item_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Work_Item);

   --  A concrete action for one work item. When Skip is True nothing is copied
   --  or moved. Otherwise the source is written to Dest_Path; Replaced is True
   --  when Dest_Path already existed and must be overwritten (an explicit
   --  Replace choice), and False for a fresh write or a uniquified rename.
   type Resolved_Action is record
      Source_Path : Files.Types.UString;
      Dest_Path   : Files.Types.UString;
      Skip        : Boolean := False;
      Replaced    : Boolean := False;
   end record;

   package Resolved_Action_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Resolved_Action);

   --  Join a destination directory and leaf name into the desired full path.
   --
   --  @param Dir Destination directory.
   --  @param Name Desired leaf name.
   --  @return The desired destination path (Dir and Name joined with '/').
   function Desired_Path
     (Dir  : String;
      Name : String)
      return String;

   --  Whether an item's desired destination already exists.
   --
   --  @param Item Work item to test.
   --  @param Existing Full destination paths known to exist.
   --  @return True when the item's desired destination is present in Existing.
   function Has_Conflict
     (Item     : Work_Item;
      Existing : Files.Types.String_Vectors.Vector)
      return Boolean;

   --  The effective per-item decision for a policy and an optional override.
   --  An explicit override wins; otherwise the policy maps to a decision
   --  (Policy_Ask stays Decision_Pending).
   --
   --  @param Policy Batch-wide policy.
   --  @param Override Per-item override (Decision_Pending when none).
   --  @return The decision that applies to the item.
   function Effective_Decision
     (Policy   : Conflict_Policy;
      Override : Item_Decision)
      return Item_Decision;

   --  Index of the first conflicting item after position After whose effective
   --  decision is still Decision_Pending, or 0 when every remaining conflict is
   --  decided (or there are no conflicts).
   --
   --  @param Items Work-list.
   --  @param Policy Batch-wide policy.
   --  @param Overrides Per-item overrides (may be empty; missing entries are Pending).
   --  @param Existing Full destination paths known to exist.
   --  @param After Only items with index greater than After are considered.
   --  @return One-based index of the next unresolved conflict, or 0 when none.
   function Next_Unresolved_Conflict
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector;
      After     : Natural := 0)
      return Natural;

   --  Resolve a whole work-list into concrete actions. Non-conflicting items are
   --  always written (uniquified only to avoid clobbering an earlier action in
   --  the same batch). Conflicting items follow their effective decision:
   --  Replace writes over the destination, Skip does nothing, Rename writes to a
   --  uniquified name that avoids both Existing and names already claimed in this
   --  batch, and an undecided conflict (Policy_Ask with no override) is skipped
   --  as the safe never-clobber default.
   --
   --  @param Items Work-list.
   --  @param Policy Batch-wide policy.
   --  @param Overrides Per-item overrides (may be empty; missing entries are Pending).
   --  @param Existing Full destination paths known to exist.
   --  @return One resolved action per work item, in order.
   function Resolve
     (Items     : Work_Item_Vectors.Vector;
      Policy    : Conflict_Policy;
      Overrides : Item_Decision_Vectors.Vector;
      Existing  : Files.Types.String_Vectors.Vector)
      return Resolved_Action_Vectors.Vector;

end Files.Paste;
