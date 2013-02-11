(** Throttles for simultaneous computations.

    A throttle is essentially a pipe to which one can feed jobs.

    A throttle schedules asynchronous jobs so that at any given point in time no more than
    [max_concurrent_jobs] jobs are running.  A job [f] is considered to be running from
    the time [f ()] is executed until the deferred returned by [f ()] becomes determined,
    or [f ()] raises.

    A throttle "dies" if one of its jobs throws an exception, and the throttle has
    [continue_on_error = false].  If a throttle dies, then all jobs in it that haven't yet
    started will be aborted, i.e. they will not start and will become determined with
    [`Aborted].  Jobs that had already started will continue, and return [`Ok] or
    [`Raised] as usual when they finish.  Attempts to enqueue a job into a dead throttle
    will fail.
*)

open Core.Std

type t with sexp_of

include Invariant.S with type t := t

(** [create ~continue_on_error ~max_concurrent_jobs] returns a throttle that will runs up
    to [max_concurrent_jobs] concurrently.

    If some job raises an exception, then the throttle will stop, unless
    [continue_on_error] is true. *)
val create
  :  continue_on_error:bool
  -> max_concurrent_jobs:int
  -> t

type 'a outcome = [ `Ok of 'a | `Aborted | `Raised of exn ]

module Job : sig
  type 'a t

  val create : (unit -> 'a Deferred.t) -> 'a t
  val result : 'a t -> 'a outcome Deferred.t
end

val enqueue_job : t -> _ Job.t -> unit

(** [enqueue t job] schedules [job] to be run as soon as possible.  Jobs are guaranteed to
    be started in the order they are [enqueue]d.

    [enqueue] raises an exception if the throttle is dead. *)
val enqueue' : t -> (unit -> 'a Deferred.t) -> 'a outcome Deferred.t
val enqueue  : t -> (unit -> 'a Deferred.t) -> 'a         Deferred.t

(** [prior_jobs_done t] becomes determined when all of the jobs that were previously
    enqueued in [t] have completed. *)
val prior_jobs_done : t -> unit Deferred.t

val num_jobs_waiting_to_start : t -> int

(** A sequencer is a throttle that is:

    - specialized to only allow one job at a time and to not continue on error, and
    - generalized to carry its own state, and enforce mutually exclusive access to that
      state by the jobs *)
module Sequencer : sig
  type 'a t

  (** create a new monitor with the specified initial state *)
  val create : ?continue_on_error:bool (* defaults to false *) -> 'a -> 'a t

  (** schedule a state-accessing operation *)
  val enqueue : 'a t -> ('a -> 'b Deferred.t) -> 'b Deferred.t

  val num_jobs_waiting_to_start : _ t -> int
end
