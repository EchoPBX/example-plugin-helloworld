package main

import (
	"time"

	"github.com/EchoPBX/echopbx-gateway/pkg/sdk"
	"go.uber.org/zap"
)

type HelloWorldPlugin struct {
	stop chan struct{}
	log  *zap.Logger
}

func (p *HelloWorldPlugin) Init(ctx sdk.Context) error {
	p.log = ctx.Log()
	p.stop = make(chan struct{})

	p.log.Info("HelloWorldPlugin initialized")

	go func() {
		t := time.NewTicker(5 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				ctx.Bus().Publish(sdk.Event{
					Type: "plugin.helloworld.tick",
					Data: map[string]interface{}{"msg": "Hello from plugin!"},
				})
				p.log.Info("HelloWorld tick")
			case <-p.stop:
				return
			}
		}
	}()

	return nil
}

func (p *HelloWorldPlugin) Stop() error {
	if p.stop != nil {
		close(p.stop)
	}
	if p.log != nil {
		p.log.Info("HelloWorldPlugin stopped")
	}
	return nil
}

// Exporta un puntero que implementa sdk.Plugin
var Plugin sdk.Plugin = &HelloWorldPlugin{}

// Aserción de interfaz (si cambia el SDK, fallará en compile-time)
var _ sdk.Plugin = (*HelloWorldPlugin)(nil)
