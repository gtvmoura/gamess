# Estacionamento Tycoon

Jogo de gestão (tycoon/idle) feito em **Godot 4.3**: você é dono de um estacionamento numa cidade pequena e precisa transformá-la em uma metrópole.

## Como jogar

Carros passam na rua e alguns decidem entrar. Eles estacionam, ficam um tempo e **pagam por hora** ao sair. Com o lucro você investe em:

| Menu | Melhoria | Efeito |
|---|---|---|
| Melhorias | **Mais Vagas** | +5 vagas por nível |
| Melhorias | **Atratividade** | Mais motoristas entram e aceitam preços maiores |
| Melhorias | **Preço por Hora** | +R$ 1/h. Acima do "preço justo" os clientes fogem! |
| Cidade | **Desenvolver a Cidade** | +30% habitantes por nível |
| Cidade | **Frota de Veículos** | Mais carros por habitante |
| Cidade | **Turbo** | Receita em dobro por 10 min (gemas) |
| Expansão | **Bairros** | Mais habitantes e um novo estacionamento (renda extra) |
| Missões | **Missões** | Recompensas em dinheiro e gemas |

A cidade evolui em 3 fases: **Cidade Inicial → Cidade em Crescimento → Metrópole**.
O jogo salva sozinho e continua faturando enquanto você está fora (até 8 h, a 50%).

### A estratégia
Aumentar só o preço espanta clientes; aumentar só as vagas não adianta se a cidade não tem carros.
Equilibre **atratividade x preço** e **cidade x vagas**.

## Instalar no celular (Android)

1. Abra a aba **Actions** do repositório no GitHub.
2. Entre na execução mais recente de **"Estacionamento Tycoon - Testes e APK Android"** (com o ✓ verde).
3. Em **Artifacts**, baixe `estacionamento-tycoon-apk` (vem em .zip), extraia e instale o `.apk`
   (permita "instalar apps de fontes desconhecidas").

## Editar o jogo

Abra a pasta `estacionamento-tycoon` no **Godot 4.3** (PC ou o app Godot Editor para Android) e aperte Play.

```
scripts/game_state.gd  economia, progressão, missões e save (autoload "Game")
scripts/world.gd       cidade, rua, estacionamento e carros
scripts/car.gd         carro desenhado por código
scripts/ui.gd          HUD e janelas
tests/run_tests.gd     testes da economia
```

Testes: `godot --headless --path . --script res://tests/run_tests.gd`
