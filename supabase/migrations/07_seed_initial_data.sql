-- 07_seed_initial_data.sql
INSERT INTO public.support_points (name, responsible_name, address, whatsapp, is_active)
VALUES
('Casa da Irmã Isabe', 'Isabe', 'Rua das Flores, 123 - Portão Azul', '11999990001', true),
('Casa da Irmã Renata', 'Renata', 'Av. Principal, 456', '11999990002', true),
('Casa da Irmã Dielly', 'Dielly', 'Rua das Palmeiras, 78', '11999990003', true),
('Casa da Irmã Laura', 'Laura', 'Rua dos Sabiás, 90', '11999990004', true)
ON CONFLICT DO NOTHING;

INSERT INTO public.responsibilities (role_key, person_name, whatsapp, help_text, display_order)
VALUES
('admin_app', 'Irmão Administrador', '11999999999', 'Para dúvidas sobre o aplicativo ou suporte de acesso ao sistema.', 1),
('manutencao', 'Irmão Manutenção', '11988888888', 'Comunique se o carrinho ou rodas precisarem de ajuste ou reparo.', 2),
('abastecimento', 'Irmão Abastecimento', '11977777777', 'Informa quando faltarem revistas, brochuras ou folhetos.', 3),
('troca_cartaz', 'Irmão Troca de Cartaz', '11966666666', 'Responsável pela atualização dos cartazes e pôsteres no carrinho.', 4)
ON CONFLICT (role_key) DO NOTHING;
