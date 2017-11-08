package docker

import (
	"context"
	"io"
	"math"
	"sort"

	"github.com/cuigh/swirl/misc"
	"github.com/cuigh/swirl/model"
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/api/types/swarm"
	"github.com/docker/docker/client"
)

// TaskList return all running tasks of a service or a node.
func TaskList(args *model.TaskListArgs) (infos []*model.TaskInfo, totalCount int, err error) {
	err = mgr.Do(func(ctx context.Context, cli *client.Client) (err error) {
		var (
			tasks []swarm.Task
			opts  = types.TaskListOptions{
				Filters: filters.NewArgs(),
			}
		)

		if args.PageIndex < 1 {
			args.PageIndex = 1
		}
		if args.PageSize < 1 {
			args.PageSize = math.MaxInt32
		}
		if args.Service != "" {
			opts.Filters.Add("service", args.Service)
		}
		if args.Node != "" {
			opts.Filters.Add("node", args.Node)
		}
		if args.Name != "" {
			opts.Filters.Add("name", args.Name)
		}
		if args.State != "" {
			opts.Filters.Add("desired-state", args.State)
		}

		tasks, err = cli.TaskList(ctx, opts)
		totalCount = len(tasks)
		if err == nil && totalCount > 0 {
			sort.Slice(tasks, func(i, j int) bool {
				return tasks[i].UpdatedAt.After(tasks[j].UpdatedAt)
			})
			start, end := misc.Page(totalCount, args.PageIndex, args.PageSize)
			tasks = tasks[start:end]

			nodes := make(map[string]string)
			for _, t := range tasks {
				if _, ok := nodes[t.NodeID]; !ok {
					if n, _, e := cli.NodeInspectWithRaw(ctx, t.NodeID); e == nil {
						if n.Spec.Name == "" {
							nodes[t.NodeID] = n.Description.Hostname
						} else {
							nodes[t.NodeID] = n.Spec.Name
						}
					} else {
						nodes[t.NodeID] = ""
					}
				}
			}

			infos = make([]*model.TaskInfo, len(tasks))
			for i, t := range tasks {
				infos[i] = model.NewTaskInfo(t, nodes[t.NodeID])
			}
		}
		return
	})
	return
}

// TaskInspect return detail information of a task.
func TaskInspect(id string) (task swarm.Task, raw []byte, err error) {
	err = mgr.Do(func(ctx context.Context, cli *client.Client) (err error) {
		task, raw, err = cli.TaskInspectWithRaw(ctx, id)
		return
	})
	return
}

// TaskLogs returns the logs generated by a task in an io.ReadCloser.
// It's up to the caller to close the stream.
func TaskLogs(id string) (rc io.ReadCloser, err error) {
	err = mgr.Do(func(ctx context.Context, cli *client.Client) (err error) {
		opts := types.ContainerLogsOptions{}
		rc, err = cli.TaskLogs(ctx, id, opts)
		return
	})
	return
}
